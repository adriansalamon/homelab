{
  config,
  lib,
  globals,
  ...
}:
let
  inherit (config.resource) consul_acl_policy;

  # Standard policies for any Consul agent node
  common_agent_policies = [
    consul_acl_policy.read_common.name
    consul_acl_policy.base_agent.name
  ];

  # Helper for agent tokens
  mkAgentToken = desc: extraPolicies: {
    description = desc;
    policies = common_agent_policies ++ extraPolicies;
  };

  # Helper for Nomad job roles
  mkNomadRole = jobName: desc: policies: {
    name = "nomad-job-default-${jobName}";
    description = "Role for ${jobName} ${desc}";
    inherit policies;
  };
in
{
  # ACL Policies
  resource.consul_acl_policy = {
    read_common = {
      name = "read-common-keys";
      description = "Base policy to read common keys";
      rules = ''
        key_prefix "config/" {
          policy = "read"
        }
        key_prefix "builds/" {
          policy = "read"
        }
      '';
    };

    base_agent = {
      name = "base-agent-policy";
      description = "Base policy for all Consul agent nodes to register services and nodes";
      rules = ''
        node_prefix "" {
          policy = "write"
        }
        service_prefix "" {
          policy = "write"
        }
        agent_prefix "" {
          policy = "read"
        }
      '';
    };

    server_policy = {
      name = "server-agent-policy";
      description = "Policy for Consul server agents with elevated permissions";
      rules = ''
        agent_prefix "" {
          policy = "write"
        }
        query_prefix "" {
          policy = "read"
        }
      '';
    };

    write_services = {
      name = "write-services";
      description = "Policy to read write services";
      rules = ''
        service_prefix "" {
          policy = "write"
        }
      '';
    };

    read_services = {
      name = "read-services";
      description = "Policy to read all services";
      rules = ''
        service_prefix "" {
          policy = "read"
        }
      '';
    };

    read_nodes = {
      name = "read-nodes";
      description = "Policy to read all nodes";
      rules = ''
        node_prefix "" {
          policy = "read"
        }
      '';
    };

    write_session = {
      name = "write-session";
      description = "Policy to write sessions";
      rules = ''
        session_prefix "" {
          policy = "write"
        }
      '';
    };

    patroni = {
      name = "patroni-policy";
      rules = ''
        key_prefix "service/homelab-cluster/" {
          policy = "write"
        }

        service "homelab-cluster" {
          policy = "write"
        }

        service "homelab-cluster-primary" {
          policy = "write"
        }

        service "homelab-cluster-replica" {
          policy = "write"
        }
      '';
    };

    nomad_server = {
      name = "nomad-server-policy";
      description = "Policy for Nomad servers to manage state in Consul";
      rules = ''
        acl  = "write"
        mesh = "write"
      '';
    };

    builds_push = {
      name = "builds-policy";
      description = "Policy for builders to push derivation paths";
      rules = ''
        key_prefix "builds/" {
          policy = "write"
        }
      '';
    };

    apply_builds = {
      name = "apply-builds-policy";
      rules = ''
        key_prefix "builds/" {
          policy = "write"
        }
        session_prefix "" {
          policy = "write"
        }
      '';
    };

    nebula_cni = {
      name = "nebula-cni";
      description = "Policy for nebula-nomad-cni plugin to manage IP allocations and allocation records";
      rules = ''
        key_prefix "nebula-cni/" {
          policy = "write"
        }
      '';
    };

    terraform = {
      name = "terraform-state";
      description = "Policy for Atlantis to manage Terraform state";
      rules = ''
        # Write Terraform state
        key_prefix "terraform/" {
          policy = "write"
        }
      '';
    };
  };

  # ACL Tokens
  resource.consul_acl_token = {
    server_token = mkAgentToken "Token for Consul server agents" [
      consul_acl_policy.server_policy.name
    ];
    agent_token = mkAgentToken "Token for Consul client agents" [ ];
    nomad_server = mkAgentToken "Token for Nomad servers" [ consul_acl_policy.nomad_server.name ];
    nomad_client = mkAgentToken "Token for Nomad clients" [ ];

    kea_ddns_token = {
      description = "Kea DDNS Token";
      policies = [ consul_acl_policy.write_services.name ];
    };

    traefik = {
      description = "Traefik Token";
      policies = [ consul_acl_policy.read_services.name ];
    };

    patroni = {
      description = "Token for patroni";
      policies = [
        consul_acl_policy.patroni.name
        consul_acl_policy.read_services.name
        consul_acl_policy.read_nodes.name
        consul_acl_policy.write_session.name
      ];
    };

    build_token = {
      description = "Token for build servers";
      policies = [ consul_acl_policy.builds_push.name ];
    };

    apply_builds = {
      description = "Token for apply builds";
      policies = [ consul_acl_policy.apply_builds.name ];
    };

    nebula_cni = {
      policies = [ consul_acl_policy.nebula_cni.name ];
    };

    vault = {
      description = "Token for Vault";
      policies = [ "global-management" ];
    };
  };

  data.consul_acl_token_secret_id.vault = {
    accessor_id = lib.tf.ref "resource.consul_acl_token.vault.id";
  };

  # Module to setup Consul with Nomad Workload Identities
  module.consul_setup = {
    source = "hashicorp-modules/nomad-setup/consul";

    nomad_jwks_url = "https://nomad.local.${globals.domains.main}/.well-known/jwks.json";

    tasks_policy_ids = [
      consul_acl_policy.read_common.name
      consul_acl_policy.read_services.name
    ];
  };

  # Dynamic binding rule: binds Nomad tasks to roles based on their job identity
  # Pattern: nomad-job-${namespace}-${job_id}
  # This allows any job to get a custom role just by creating a role with the right name
  resource.consul_acl_binding_rule.nomad_tasks_to_job_roles = {
    auth_method = "nomad-workloads";
    description = "Bind Nomad tasks to job-specific roles";

    # Only select tasks (not services), and bind them to a role named after their job
    selector = ''"nomad_service" not in value'';

    bind_type = "role";
    bind_name = "nomad-job-\$\${value.nomad_namespace}-\$\${value.nomad_job_id}";
  };

  resource.consul_acl_role = {
    nomad_job_default_vmalert = mkNomadRole "vmalert" "for consul service discovery" [
      consul_acl_policy.base_agent.name
    ];
    nomad_job_default_prometheus = mkNomadRole "prometheus" "for consul service discovery" [
      consul_acl_policy.base_agent.name
    ];
  };
}
