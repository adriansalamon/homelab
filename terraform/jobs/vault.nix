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

  # Consul secrets engine
  resource.vault_consul_secret_backend.consul = {
    path = "consul";
    description = "Consul Secrets Engine for dynamic ACL tokens";
    address = "https://consul.local.\${var.domain}";
    token_wo = "\${var.consul_bootstrap_token}";
    token_wo_version = 1;

    lifecycle = {
      prevent_destroy = true;
    };
  };

  resource.vault_consul_secret_backend_role.example_client = {
    name = "example-client-role";
    backend = "\${vault_consul_secret_backend.consul.path}";

    consul_policies = [
      "\${consul_acl_policy.base_agent.name}"
    ];

    ttl = 3600;
    max_ttl = 86400;
  };

  # Module to setup Vault with Nomad Workload Identities
  module.vault_setup = {
    source = "./vault-nomad-setup";

    nomad_jwks_url = "\${var.nomad_url}/.well-known/jwks.json";

    policy_names = [
      "\${vault_policy.nomad_workloads.name}"
    ];
  };

  # Policy for regular Nomad workloads (namespace/job-scoped secrets)
  resource.vault_policy.nomad_workloads = {
    name = "nomad-workloads";
    policy = ''
      path "secret/data/{{identity.entity.aliases.''${module.vault_setup.auth_backend_accessor}.metadata.nomad_namespace}}/{{identity.entity.aliases.''${module.vault_setup.auth_backend_accessor}.metadata.nomad_job_id}}/*" {
        capabilities = ["read"]
      }

      path "secret/data/{{identity.entity.aliases.''${module.vault_setup.auth_backend_accessor}.metadata.nomad_namespace}}/{{identity.entity.aliases.''${module.vault_setup.auth_backend_accessor}.metadata.nomad_job_id}}" {
        capabilities = ["read"]
      }

      path "secret/metadata/{{identity.entity.aliases.''${module.vault_setup.auth_backend_accessor}.metadata.nomad_namespace}}/*" {
        capabilities = ["list"]
      }

      path "secret/metadata/*" {
        capabilities = ["list"]
      }
    '';
  };

  # Policy for GitHub Actions runner to manage Vault configuration via Terraform
  resource.vault_policy.github_runner_terraform = {
    name = "github-runner-terraform";
    policy = ''
      # Allow managing policies
      path "sys/policies/acl/*" {
        capabilities = ["create", "read", "update", "delete", "list"]
      }

      path "sys/policies/acl" {
        capabilities = ["list"]
      }

      # Allow managing JWT auth backends and roles
      path "auth/jwt/*" {
        capabilities = ["create", "read", "update", "delete", "list"]
      }

      path "auth/oidc/*" {
        capabilities = ["create", "read", "update", "delete", "list"]
      }

      # Allow reading auth backend configuration (needed for Terraform)
      path "sys/auth" {
        capabilities = ["read", "list"]
      }

      path "sys/auth/*" {
        capabilities = ["read", "list"]
      }

      # Allow managing secret engine mounts (but NOT deleting them)
      # Note: prevent_destroy lifecycle rule in Terraform will prevent deletion
      path "sys/mounts/*" {
        capabilities = ["create", "read", "update", "list"]
      }

      path "sys/mounts" {
        capabilities = ["read", "list"]
      }

      # Allow managing secret engine configurations
      path "consul/config/*" {
        capabilities = ["create", "read", "update", "delete", "list"]
      }

      path "consul/roles/*" {
        capabilities = ["create", "read", "update", "delete", "list"]
      }

      # Allow reading Consul backend configuration
      path "consul/config/access" {
        capabilities = ["read"]
      }

      # Allow reading namespace/job-scoped secrets for the runner itself
      path "secret/data/default/github-runner/*" {
        capabilities = ["read"]
      }

      path "secret/metadata/default/*" {
        capabilities = ["list"]
      }
    '';
  };

  resource.vault_identity_entity.github_runner = {
    name = "github-runner";
    policies = [ "\${vault_policy.github_runner_terraform.name}" ];
  };

  resource.vault_identity_entity_alias.github_runner = {
    # Match the nomad_job_id claim
    name = "github-runner";

    mount_accessor = "\${module.vault_setup.auth_backend_accessor}";
    canonical_id = "\${vault_identity_entity.github_runner.id}";
  };
}
