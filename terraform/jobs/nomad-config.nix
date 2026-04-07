{
  config,
  lib,
  globals,
  ...
}:
{
  # ACL Policies
  resource.nomad_acl_policy = {
    admin = {
      name = "admin";
      description = "Policy for admin users";
      rules_hcl = ''
        namespace "*" {
          policy = "write"

          variables {
            path "*" {
              capabilities = ["write", "read", "destroy", "list"]
            }
          }
        }

        node {
          policy = "write"
        }

        agent {
          policy = "write"
        }

        host_volume "*" {
          policy = "write"
        }

        plugin {
          policy = "write"
        }
      '';
    };

    operator = {
      name = "nomad-gitops-operator";
      rules_hcl = ''
        namespace "*" {
          policy = "write"
        }

        host_volume "*" {
          policy = "write"
        }
      '';
    };

    nebula_cni = {
      name = "nebula-cni";
      description = "Policy for nebula-nomad-cni plugin to read allocations and nodes";
      rules_hcl = ''
        # Required to get allocation details including task metadata
        namespace "*" {
          capabilities = ["read-job", "list-jobs"]
        }

        # To list nodes and get node allocations
        node {
          policy = "read"
        }
      '';
    };

    github_runner_dispatch = {
      name = "github-runner-dispatch";
      description = "Policy for GitHub webhook to dispatch runner jobs";
      rules_hcl = ''
        namespace "*" {
          policy       = "read"
          capabilities = ["dispatch-job"]
        }
      '';

      job_acl = {
        namespace = "default";
        job_id = "github-webhook";
      };
    };

    github_runner_terraform = {
      name = "github-runner-terraform";
      description = "Policy for GitHub Actions runner to manage Nomad ACL configuration via Terraform";
      inherit (config.resource.nomad_acl_policy.admin) rules_hcl;

      job_acl = {
        namespace = "default";
        job_id = "github-runner";
      };
    };
  };

  # ACL Tokens
  resource.nomad_acl_token = {
    operator_token = {
      type = "client";
      policies = [ config.resource.nomad_acl_policy.operator.name ];
    };

    nebula_cni = {
      name = "nebula-cni";
      type = "client";
      policies = [ config.resource.nomad_acl_policy.nebula_cni.name ];
    };

    atlantis = {
      name = "atlantis";
      type = "client";
      policies = [ config.resource.nomad_acl_policy.operator.name ];
    };

    vault = {
      name = "vault";
      type = "management";
    };
  };

  # OIDC Authentication via Authelia
  resource.nomad_acl_auth_method.authelia = {
    name = "authelia";
    max_token_ttl = "24h0m0s";
    token_locality = "global";
    type = "OIDC";
    token_name_format = "authelia-\$\${value.username}";

    config = {
      oidc_discovery_url = "https://auth.${globals.domains.main}";
      oidc_client_id = "nomad";
      oidc_client_secret = lib.tf.ref "data.vault_kv_secret_v2.oidc_client_secrets.data.nomad";
      bound_audiences = [ "nomad" ];
      allowed_redirect_uris = [
        "https://nomad.local.${globals.domains.main}/ui/settings/tokens"
        "http://localhost:4649/oidc/callback"
      ];
      oidc_scopes = [
        "openid"
        "profile"
        "groups"
      ];
      claim_mappings = {
        preferred_username = "username";
      };
      list_claim_mappings = {
        groups = "groups";
      };
    };
  };

  resource.nomad_acl_binding_rule.authelia_admin = {
    auth_method = config.resource.nomad_acl_auth_method.authelia.name;
    selector = "admin in list.groups";
    bind_type = "policy";
    bind_name = config.resource.nomad_acl_policy.admin.name;
  };

  # Scheduler configuration
  resource.nomad_scheduler_config.scheduler = {
    memory_oversubscription_enabled = true;
    preemption_config = {
      batch_scheduler_enabled = false;
      service_scheduler_enabled = false;
      sysbatch_scheduler_enabled = false;
      system_scheduler_enabled = false;
    };
  };
}
