{
  config,
  lib,
  globals,
  ...
}:
let

  mkNomadRoleMapping =
    {
      name,
      job_id ? null,
      policies,
    }:
    {
      backend = config.resource.vault_jwt_auth_backend.nomad.path;
      role_name = name;
      role_type = "jwt";

      bound_audiences = [ "vault.io" ];

      user_claim = "/nomad_job_id";
      user_claim_json_pointer = true;

      claim_mappings = {
        nomad_namespace = "nomad_namespace";
        nomad_job_id = "nomad_job_id";
        nomad_group = "nomad_group";
        nomad_task = "nomad_task";
      };

      token_type = "service";
      token_policies = policies;

      token_period = 3600;
      token_explicit_max_ttl = 0;
    }
    // lib.optionalAttrs (job_id != null) {
      bound_claims = {
        nomad_job_id = job_id;
      };
    };

in

{
  # Admin policy for OIDC users
  resource.vault_policy.admin = {
    name = "admin";
    policy = ''
      path "*" {
        capabilities = ["create", "read", "update", "delete", "list", "sudo"]
      }
    '';
  };

  ephemeral.vault_kv_secret_v2.oidc_client_secrets = {
    mount = config.resource.vault_mount.kvv2.path;
    mount_id = lib.tf.ref "vault_mount.kvv2.id";
    name = "oidc_client_secrets";
  };

  data.vault_kv_secret_v2.oidc_client_secrets = {
    mount = config.resource.vault_mount.kvv2.path;
    name = "oidc_client_secrets";
  };

  # OIDC authentication via Authelia
  resource.vault_jwt_auth_backend.authelia = {
    description = "Authelia OIDC";
    path = "oidc";
    type = "oidc";
    oidc_discovery_url = "https://auth.${globals.domains.main}";
    oidc_client_id = "vault";
    oidc_client_secret_wo = "\${ephemeral.vault_kv_secret_v2.oidc_client_secrets.data.vault}";
    oidc_client_secret_wo_version = 1;
    default_role = "admin";

  };

  resource.vault_jwt_auth_backend_role.admin = {
    backend = config.resource.vault_jwt_auth_backend.authelia.path;
    role_name = "admin";
    token_policies = [ config.resource.vault_policy.admin.name ];

    user_claim = "preferred_username";
    groups_claim = "groups";

    oidc_scopes = [
      "openid"
      "profile"
      "groups"
      "email"
    ];

    allowed_redirect_uris = [
      "https://vault.local.${globals.domains.main}/ui/vault/auth/oidc/oidc/callback"
      "http://localhost:8250/oidc/callback"
    ];

    bound_claims_type = "string";
    bound_claims = {
      groups = "admin";
    };
  };

  # KV v2 secret engine
  resource.vault_mount.kvv2 = {
    path = "secret";
    type = "kv";
    options = {
      version = "2";
    };
    description = "Standard KV-V2 Mount";

    lifecycle = {
      prevent_destroy = true;
    };
  };

  resource.vault_jwt_auth_backend.nomad = {
    path = "jwt-nomad";
    description = "JWT auth backend for Nomad";
    jwks_url = "https://nomad.local.${globals.domains.main}/.well-known/jwks.json";
    jwt_supported_algs = [
      "RS256"
      "EdDSA"
    ];

    default_role = "nomad-workloads";
  };

  # Policy for regular Nomad workloads (namespace/job-scoped secrets)
  resource.vault_policy.nomad_workloads = {
    name = "nomad-workloads";
    policy = ''
      path "secret/data/{{identity.entity.aliases.''${vault_jwt_auth_backend.nomad.accessor}.metadata.nomad_namespace}}/{{identity.entity.aliases.''${vault_jwt_auth_backend.nomad.accessor}.metadata.nomad_job_id}}/*" {
        capabilities = ["read"]
      }

      path "secret/data/{{identity.entity.aliases.''${vault_jwt_auth_backend.nomad.accessor}.metadata.nomad_namespace}}/{{identity.entity.aliases.''${vault_jwt_auth_backend.nomad.accessor}.metadata.nomad_job_id}}" {
        capabilities = ["read"]
      }

      path "secret/metadata/{{identity.entity.aliases.''${vault_jwt_auth_backend.nomad.accessor}.metadata.nomad_namespace}}/*" {
        capabilities = ["list"]
      }

      path "secret/metadata/*" {
        capabilities = ["list"]
      }
    '';
  };

  # Default Nomad workload role
  resource.vault_jwt_auth_backend_role.nomad_workload = mkNomadRoleMapping {
    name = config.resource.vault_jwt_auth_backend.nomad.default_role;

    policies = [ config.resource.vault_policy.nomad_workloads.name ];
  };

  # Nomad workload role for the github-runner job
  resource.vault_jwt_auth_backend_role.github_runner = mkNomadRoleMapping {
    name = "github-runner";
    job_id = "github-runner";
    policies = [ config.resource.vault_policy.admin.name ];
  };

  resource.vault_policy.postgres_backup = {
    name = "postgres-backup";
    policy = ''
      # Allow getting dynamic PostgreSQL credentials
      path "database/creds/backup" {
        capabilities = ["read"]
      }
    '';
  };

  resource.vault_jwt_auth_backend_role.postgres_backup = mkNomadRoleMapping {
    name = "postgres-backup";
    job_id = "backup-postgres";

    policies = [
      config.resource.vault_policy.nomad_workloads.name
      config.resource.vault_policy.postgres_backup.name
    ];
  };

  resource.vault_policy.vault_backup = {
    name = "vault-backup";
    policy = ''
      # Allow creating Vault raft snapshots
      path "sys/storage/raft/snapshot" {
        capabilities = ["read"]
      }
    '';
  };

  resource.vault_jwt_auth_backend_role.vault_backup = mkNomadRoleMapping {
    name = "vault-backup";
    job_id = "backup-vault";

    policies = [
      config.resource.vault_policy.nomad_workloads.name
      config.resource.vault_policy.vault_backup.name
    ];
  };

  # We need a nomad vault backend to be able to request nomad management tokens
  resource.vault_nomad_secret_backend.config = {
    backend = "nomad";

    address = "https://nomad.local.${globals.domains.main}";
    token = lib.tf.ref "nomad_acl_token.vault.secret_id";

    default_lease_ttl_seconds = "3600";
    max_lease_ttl_seconds = "7200";
  };

  resource.vault_nomad_secret_role.admin = {
    backend = lib.tf.ref "vault_nomad_secret_backend.config.backend";
    role = "admin";
    type = "management"; # specific token to be able to configure nomad
  };

  # Transit secrets engine for encrypting/decrypting secrets
  resource.vault_mount.transit = {
    path = "transit";
    type = "transit";
    description = "Transit Secrets Engine";
  };

  # Transit keys (SOPS keys for decrypting secrets)
  resource.vault_transit_secret_backend_key = lib.listToAttrs (
    map
      (name: {
        name = lib.replaceStrings [ "-" ] [ "_" ] name;
        value = {
          backend = config.resource.vault_mount.transit.path;
          inherit name;
          deletion_allowed = false;
        };
      })
      [
        "sops-key"
        "git-homelab"
      ]
  );

  # Nebula Vault Plugin registration
  resource.vault_plugin.nebula = {
    name = "nebula-vault-plugin";
    type = "secret";
    command = "vault-plugin-nebula";
    sha256 = "eeca86cbe0638ff8cabb33d6a116fe1577014866db74f3e94bed3ea46a7e53cb";
  };

  # Enable the Nebula secrets engine
  resource.vault_mount.nebula = {
    path = "nebula";
    type = config.resource.vault_plugin.nebula.name;
    description = "Nebula secrets engine for certificate management";
  };

  # Policy for nebula-nomad-cni to issue certificates
  resource.vault_policy.nebula_cni = {
    name = "nebula-cni";
    policy = ''
      # Allow signing certificates
      path "nebula/sign" {
        capabilities = ["create", "update"]
      }

      # Allow reading CA certificate
      path "nebula/ca" {
        capabilities = ["read"]
      }
    '';
  };

  # AppRole for nebula-nomad-cni agents
  resource.vault_auth_backend.approle = {
    type = "approle";
    path = "approle";
  };

  resource.vault_approle_auth_backend_role.nebula_cni = {
    backend = lib.tf.ref "vault_auth_backend.approle.path";
    role_name = "nebula-cni";
    token_policies = [ config.resource.vault_policy.nebula_cni.name ];
    token_ttl = 3600;
    token_max_ttl = 7200;
  };

  # Fetch the Patroni superuser password from Vault KV
  ephemeral.vault_kv_secret_v2.patroni_superuser_password = {
    mount = config.resource.vault_mount.kvv2.path;
    name = "patroni/superuser-password";
  };

  # PostgreSQL secrets engine for Patroni cluster
  resource.vault_database_secrets_mount.patroni = {
    path = "database";

    postgresql = [
      {
        name = "patroni";
        plugin_name = "postgresql-database-plugin";

        # Connect to Patroni primary via Consul DNS
        connection_url = "postgresql://{{username}}:{{password}}@primary.homelab-cluster.service.consul:5432/postgres";

        # Use the superuser credentials for managing dynamic users
        username = "postgres";
        password_wo = "\${ephemeral.vault_kv_secret_v2.patroni_superuser_password.data.password}";
        password_wo_version = 1;

        allowed_roles = [ "*" ];

        # Verify connection on creation
        verify_connection = true;
      }
    ];
  };

  # Role for backup jobs - read-only access to all databases
  resource.vault_database_secret_backend_role.backup = {
    backend = lib.tf.ref "vault_database_secrets_mount.patroni.path";
    name = "backup";
    db_name = "patroni";

    creation_statements = [
      "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' IN ROLE pg_read_all_data;"
    ];

    default_ttl = 3600;
    max_ttl = 7200;
  };
}
