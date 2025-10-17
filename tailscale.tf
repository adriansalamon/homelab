provider "tailscale" {
  api_key = var.tailscale_api_key
  tailnet = var.tailnet
}

data "local_file" "tailscale_config" {
  filename = "${path.module}/.terraform/tailscale-config.json"
}

locals {
  config = jsondecode(data.local_file.tailscale_config.content)
}

resource "tailscale_acl" "main" {
  acl = jsonencode({
    groups = {
      "group:salamon" = [
        for user in local.config.users : "${user}@${local.config.domains.alt}"
      ]
    }

    tagOwners = {
      "tag:gateway" = ["group:salamon"]
    }

    acls = [
      {
        action = "accept"
        src    = ["group:salamon"]
        dst    = [for site in local.config.sites : "${site.lan_cidr}:*"]
      },
      {
        action = "accept"
        src    = ["tag:gateway"]
        dst    = ["100.64.0.0/10:*", "autogroup:internet:*"]
      }
    ]

    ssh = [
      {
        action = "accept"
        src    = ["group:salamon"]
        dst    = ["tag:gateway"]
        users  = ["autogroup:nonroot"]
      }
    ],

    autoApprovers = {
      routes = {
        for site in local.config.sites : site.lan_cidr => ["tag:gateway"]
      }
    }
  })
}

resource "tailscale_dns_nameservers" "dns_nameservers" {
  nameservers = [
    "1.1.1.1",
    "1.0.0.1"
  ]
}

resource "tailscale_dns_split_nameservers" "domains" {
  for_each = toset(local.config.internal_domains)

  domain      = each.value
  nameservers = [for site in local.config.sites : site.dns_server]
}

resource "tailscale_dns_preferences" "dns_preferences" {
  magic_dns = true
}

resource "tailscale_dns_search_paths" "dns_search_paths" {
  search_paths = []
}
