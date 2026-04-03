# Nomad platform configuration
# Migrated from terraform/infra/nomad.tf
{ ... }:
{
  # ACL Policies
  resource.nomad_acl_policy = {
    admin = {
      name = "admin";
      description = "Policy for admin users";
      rules_hcl = ''
        namespace "*" {
          policy = "write"
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
      rules_hcl = ''
        # Allow managing ACL policies
        namespace "*" {
          policy = "write"
          capabilities = [
            "submit-job",
            "dispatch-job",
            "read-logs",
            "read-fs",
            "read-job",
            "list-jobs",
          ]
        }

        # Allow managing auth methods and binding rules
        operator {
          policy = "write"
        }

        # Allow reading nodes (for Terraform data sources)
        node {
          policy = "read"
        }

        # Allow managing host volumes
        host_volume "*" {
          policy = "write"
        }

        # Allow reading plugin information
        plugin {
          policy = "read"
        }
      '';

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
      policies = [ "\${nomad_acl_policy.operator.name}" ];
    };

    nebula_cni = {
      name = "nebula-cni";
      type = "client";
      policies = [ "\${nomad_acl_policy.nebula_cni.name}" ];
    };

    atlantis = {
      name = "atlantis";
      type = "client";
      policies = [ "\${nomad_acl_policy.operator.name}" ];
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
      oidc_discovery_url = "https://auth.\${var.domain}";
      oidc_client_id = "nomad";
      oidc_client_secret = "\${var.nomad_oidc_client_secret}";
      bound_audiences = [ "nomad" ];
      allowed_redirect_uris = [
        "\${var.nomad_url}/ui/settings/tokens"
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
    auth_method = "\${nomad_acl_auth_method.authelia.name}";
    selector = "admin in list.groups";
    bind_type = "policy";
    bind_name = "\${nomad_acl_policy.admin.name}";
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
