// If you are not in the nebula network, you need to set up an ssh tunnel
// to a host in the nebula network and with access to a consul server.
// You can do this by running:
// ssh -L 15432:<nebula-ip-of-consul-server>:8500 <user>@<host>
provider "consul" {
  address = "http://localhost:15432"
  token   = var.consul_bootstrap_token
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
key_prefix "config/" {
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

resource "consul_acl_policy" "kea_ddns" {
  name        = "kea-ddns-policy"
  description = "Policy for kea-ddns service"
  rules       = <<EOT
service_prefix "" {
  policy = "write"
}
EOT
}

resource "consul_acl_policy" "traefik" {
  name        = "traefik-policy"
  description = "Policy for traefik service"
  rules       = <<EOT
service_prefix "" {
  policy = "read"
}
EOT
}

resource "consul_acl_policy" "homepage" {
  name        = "homepage-policy"
  description = "Policy for homepage to read nodes"
  rules       = <<EOT
node_prefix "" {
  policy = "read"
}
EOT
}

resource "consul_acl_policy" "patroni" {
  name  = "patroni-policy"
  rules = <<EOT
key_prefix "service/homelab-cluster/" {
  policy = "write"
}

session_prefix "" {
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

service_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
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


resource "consul_acl_token" "server_token" {
  description = "Token for Consul server agents"
  policies = [
    consul_acl_policy.base_agent.name,
    consul_acl_policy.server_policy.name
  ]
}

resource "consul_acl_token" "agent_token" {
  description = "Token for Consul client agents"
  policies    = [consul_acl_policy.base_agent.name]
}

resource "consul_acl_token" "kea_ddns_token" {
  description = "Kea DDNS Token"
  policies    = [consul_acl_policy.kea_ddns.name]
}

resource "consul_acl_token" "traefik" {
  description = "Traefik Token"
  policies    = [consul_acl_policy.traefik.name]
}

resource "consul_acl_token" "homepage" {
  description = "Homepage Token"
  policies    = [consul_acl_policy.homepage.name]
}

resource "consul_acl_token" "patroni" {
  description = "Token for patroni"
  policies    = [consul_acl_policy.patroni.name]
}

resource "consul_acl_token" "nomad_server" {
  description = "Token for Nomad servers"
  policies = [
    consul_acl_policy.nomad_server.name,
    consul_acl_policy.base_agent.name
  ]
}

resource "consul_acl_token" "nomad_client" {
  description = "Token for Nomad clients"
  policies    = [consul_acl_policy.base_agent.name]
}

data "consul_acl_token_secret_id" "server_token" {
  accessor_id = consul_acl_token.server_token.id
}

data "consul_acl_token_secret_id" "agent_token" {
  accessor_id = consul_acl_token.agent_token.id
}

data "consul_acl_token_secret_id" "kea_ddns_token" {
  accessor_id = consul_acl_token.kea_ddns_token.id
}

data "consul_acl_token_secret_id" "traefik" {
  accessor_id = consul_acl_token.traefik.id
}

data "consul_acl_token_secret_id" "homepage" {
  accessor_id = consul_acl_token.homepage.id
}

data "consul_acl_token_secret_id" "patroni" {
  accessor_id = consul_acl_token.patroni.id
}

data "consul_acl_token_secret_id" "nomad_server" {
  accessor_id = consul_acl_token.nomad_server.id
}

data "consul_acl_token_secret_id" "nomad_client" {
  accessor_id = consul_acl_token.nomad_client.id
}

locals {
  acl_tokens = {
    server       = data.consul_acl_token_secret_id.server_token
    agent        = data.consul_acl_token_secret_id.agent_token
    nomad_server = data.consul_acl_token_secret_id.nomad_server
    nomad_client = data.consul_acl_token_secret_id.nomad_client
  }

  tokens = {
    kea_ddns = data.consul_acl_token_secret_id.kea_ddns_token
    traefik  = data.consul_acl_token_secret_id.traefik
  }
}

# Module to setup Consul with Nomad Workload Identities
module "consul_setup" {
  source = "hashicorp-modules/nomad-setup/consul"

  nomad_jwks_url = "${var.nomad_url}/.well-known/jwks.json"
}

# Optional: Uncomment to generate gossip key file for encryption
# resource "local_file" "nomad_gossip_key" {
#   filename        = "secrets/nomad/gossip-key"
#   file_permission = "0600"
#   content         = local.nomad_gossip_key_b64
#   provisioner "local-exec" {
#     command     = <<BASH
#       filename="secrets/nomad/gossip-key"
#       rm "$filename.age"
#       rage -i $IDENTITY_FILE -e "$filename" -o "$filename.age"
#       rm $filename
#     BASH
#     working_dir = "."
#   }
# }

# // local exec to create the acl
# //
# // uncomment this if you want to recreate acls and tokens
# // this is mostly idempotent, but will create new age files with different salts
# resource "local_file" "acl" {
#   for_each = local.acl_tokens

#   filename        = "secrets/consul/${each.key}.acl.json"
#   file_permission = "0600"
#   content         = <<EOT
# {
#   "acl": {
#     "tokens": {
#       "default": "${each.value.secret_id}"
#     }
#   }
# }
# EOT
#   provisioner "local-exec" {
#     command     = <<BASH
#       filename="secrets/consul/${each.key}.acl.json"
#       rm "$filename.age"
#       rage -i $IDENTITY_FILE -e "$filename" -o "$filename.age"
#       rm $filename
#     BASH
#     working_dir = "."
#   }
# }

# resource "local_file" "token" {
#   for_each = local.tokens

#   filename        = "secrets/consul/${each.key}"
#   file_permission = "0600"
#   content         = each.value.secret_id
#   provisioner "local-exec" {
#     command     = <<BASH
#       filename="secrets/consul/${each.key}"
#       rm "$filename.age"
#       rage -i $IDENTITY_FILE -e "$filename" -o "$filename.age"
#       rm $filename
#     BASH
#     working_dir = "."
#   }
# }
