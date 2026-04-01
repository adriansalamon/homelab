resource "consul_acl_policy" "read_common" {
  name        = "read-common-keys"
  description = "Base policy to read common keys"
  rules       = <<EOT
key_prefix "config/" {
  policy = "read"
}
key_prefix "builds/" {
  policy = "read"
}
EOT
}

resource "consul_acl_policy" "base_agent" {
  name        = "base-agent-policy"
  description = "Base policy for all Consul agent nodes to register services and nodes"
  rules       = <<EOT
node_prefix "" {
  policy = "write"
}
service_prefix "" {
  policy = "write"
}
agent_prefix "" {
  policy = "read"
}
EOT
}

resource "consul_acl_policy" "server_policy" {
  name        = "server-agent-policy"
  description = "Policy for Consul server agents with elevated permissions"
  rules       = <<EOT
agent_prefix "" {
  policy = "write"
}
query_prefix "" {
  policy = "read"
}
EOT
}

resource "consul_acl_policy" "write_services" {
  name        = "write-services"
  description = "Policy to read write services"
  rules       = <<EOT
service_prefix "" {
  policy = "write"
}
EOT
}

resource "consul_acl_policy" "read_services" {
  name        = "read-services"
  description = "Policy to read all services"
  rules       = <<EOT
service_prefix "" {
  policy = "read"
}
EOT
}

resource "consul_acl_policy" "read_nodes" {
  name        = "read-nodes"
  description = "Policy to read all nodes"
  rules       = <<EOT
node_prefix "" {
  policy = "read"
}
EOT
}

resource "consul_acl_policy" "write_session" {
  name        = "write-session"
  description = "Policy to wrtie sessions"
  rules       = <<EOT
session_prefix "" {
  policy = "write"
}
EOT
}

resource "consul_acl_policy" "patroni" {
  name  = "patroni-policy"
  rules = <<EOT
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
  EOT
}

resource "consul_acl_policy" "nomad_server" {
  name        = "nomad-server-policy"
  description = "Policy for Nomad servers to manage state in Consul"
  rules       = <<EOT
acl  = "write"
mesh = "write"
EOT
}

resource "consul_acl_policy" "builds_push" {
  name        = "builds-policy"
  description = "Policy for builders to push derivation paths"
  rules       = <<EOT
key_prefix "builds/" {
  policy = "write"
}
EOT
}

resource "consul_acl_policy" "apply_builds" {
  name  = "apply-builds-policy"
  rules = <<EOT
key_prefix "builds/" {
  policy = "write"
}
session_prefix "" {
  policy = "write"
}
EOT
}

resource "consul_acl_policy" "nebula_cni" {
  name        = "nebula-cni"
  description = "Policy for nebula-nomad-cni plugin to manage IP allocations and allocation records"
  rules       = <<EOT
key_prefix "nebula-cni/" {
  policy = "write"
}
EOT
}

resource "consul_acl_policy" "terraform" {
  name        = "terraform-state"
  description = "Policy for Atlantis to manage Terraform state"
  rules       = <<EOT
# Write Terraform state
key_prefix "terraform/" {
  policy = "write"
}
EOT
}

resource "consul_acl_token" "server_token" {
  description = "Token for Consul server agents"
  policies = [
    consul_acl_policy.read_common.name,
    consul_acl_policy.base_agent.name,
    consul_acl_policy.server_policy.name
  ]
}

resource "consul_acl_token" "agent_token" {
  description = "Token for Consul client agents"
  policies    = [consul_acl_policy.read_common.name, consul_acl_policy.base_agent.name]
}

resource "consul_acl_token" "kea_ddns_token" {
  description = "Kea DDNS Token"
  policies    = [consul_acl_policy.write_services.name]
}

resource "consul_acl_token" "traefik" {
  description = "Traefik Token"
  policies    = [consul_acl_policy.read_services.name]
}

resource "consul_acl_token" "patroni" {
  description = "Token for patroni"
  policies = [
    consul_acl_policy.patroni.name,
    consul_acl_policy.read_services.name,
    consul_acl_policy.read_nodes.name,
    consul_acl_policy.write_session.name
  ]
}

resource "consul_acl_token" "nomad_server" {
  description = "Token for Nomad servers"
  policies = [
    consul_acl_policy.read_common.name,
    consul_acl_policy.nomad_server.name,
    consul_acl_policy.base_agent.name
  ]
}

resource "consul_acl_token" "nomad_client" {
  description = "Token for Nomad clients"
  policies    = [consul_acl_policy.read_common.name, consul_acl_policy.base_agent.name]
}

resource "consul_acl_token" "build_token" {
  description = "Token for build servers"
  policies    = [consul_acl_policy.builds_push.name]
}

resource "consul_acl_token" "apply_builds" {
  description = "Token for apply builds"
  policies    = [consul_acl_policy.apply_builds.name]
}

resource "consul_acl_token" "nebula_cni" {
  policies = [consul_acl_policy.nebula_cni.name]
}


resource "consul_acl_token" "atlantis" {
  description = "Token for Atlantis"
  policies = [
    consul_acl_policy.terraform.name,
    consul_acl_policy.base_agent.name,
    consul_acl_policy.write_session.name
  ]
}

# Module to setup Consul with Nomad Workload Identities
module "consul_setup" {
  source = "hashicorp-modules/nomad-setup/consul"

  nomad_jwks_url = "${var.nomad_url}/.well-known/jwks.json"

  tasks_policy_ids = [
    consul_acl_policy.read_common.name,
    consul_acl_policy.read_services.name
  ]
}
