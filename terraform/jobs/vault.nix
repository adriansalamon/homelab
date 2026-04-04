# Vault platform configuration
# Migrated from terraform/infra/vault.tf
{ ... }:
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

  # OIDC authentication via Authelia
  resource.vault_jwt_auth_backend.authelia = {
    description = "Authelia OIDC";
    path = "oidc";
    type = "oidc";
    oidc_discovery_url = "https://auth.\${var.domain}";
    oidc_client_id = "vault";
    oidc_client_secret_wo = "\${var.authelia_oidc_client_secret}";
    oidc_client_secret_wo_version = 1;
    default_role = "admin";

  };

  resource.vault_jwt_auth_backend_role.admin = {
    backend = "\${vault_jwt_auth_backend.authelia.path}";
    role_name = "admin";
    token_policies = [ "\${vault_policy.admin.name}" ];

    user_claim = "preferred_username";
    groups_claim = "groups";

    oidc_scopes = [
      "openid"
      "profile"
      "groups"
      "email"
    ];

    allowed_redirect_uris = [
      "https://vault.local.\${var.domain}/ui/vault/auth/oidc/oidc/callback"
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
    jwks_url = "\${var.nomad_url}/.well-known/jwks.json";
    jwt_supported_algs = [
      "RS256"
      "EdDSA"
    ];

    default_role = "nomad-workloads";
  };

  resource.vault_jwt_auth_backend_role.nomad_workload = {
    backend = "\${vault_jwt_auth_backend.nomad.path}";
    role_name = "\${vault_jwt_auth_backend.nomad.default_role}";
    role_type = "jwt";

    bound_audiences = [ "vault.io" ];

    # user_claim is used to uniquely identity a user in Vault by mapping tokens
    # to an entity alias.
    user_claim = "/nomad_job_id";
    user_claim_json_pointer = true;

    claim_mappings = {
      nomad_namespace = "nomad_namespace";
      nomad_job_id = "nomad_job_id";
      nomad_group = "nomad_group";
      nomad_task = "nomad_task";
    };

    # token_type should be "service" so Nomad can renew them throughout the
    # task's lifecycle.
    token_type = "service";
    token_policies = [
      "\${vault_policy.nomad_workloads.name}"
    ];

    token_period = 3600;
    token_explicit_max_ttl = 0;
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

  resource.vault_identity_entity.github_runner = {
    name = "github-runner";
    # the ci runner provisions vault itself, so needs very broad access
    policies = [ "\${vault_policy.admin.name}" ];
  };

  resource.vault_identity_entity_alias.github_runner = {
    # Match the nomad_job_id claim
    name = "github-runner";

    mount_accessor = "\${vault_jwt_auth_backend.nomad.accessor}";
    canonical_id = "\${vault_identity_entity.github_runner.id}";
  };

  # We need a nomad vault backend to be able to request nomad management tokens
  resource.vault_nomad_secret_backend.config = {
    backend = "nomad";

    address = "\${var.nomad_url}";
    token = "\${nomad_acl_token.vault.secret_id}";

    default_lease_ttl_seconds = "3600";
    max_lease_ttl_seconds = "7200";
  };

  resource.vault_nomad_secret_role.admin = {
    backend = "\${vault_nomad_secret_backend.config.backend}";
    role = "admin";
    type = "management"; # specific token to be able to configure nomad
  };

  # Transit secrets engine for encrypting/decrypting secrets
  resource.vault_mount.transit = {
    path = "transit";
    type = "transit";
    description = "Transit Secrets Engine";
  };

  # SOPS key for for decrypting nomad secrets (secrets/rekeyed/nomad/*)
  resource.vault_transit_secret_backend_key.sops_key = {
    backend = "\${vault_mount.transit.path}";
    name = "sops-key";
    deletion_allowed = false;
  };

  # SOPS key for decrypting nix files in repo, eg. globals.nix
  resource.vault_transit_secret_backend_key.git_homelab = {
    backend = "\${vault_mount.transit.path}";
    name = "git-homelab";
    deletion_allowed = false;
  };
}
