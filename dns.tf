provider "cloudflare" {
  api_key = var.cloudflare_api_token
  email   = var.cloudflare_email
}

data "cloudflare_accounts" "main" {}
resource "cloudflare_zone" "salamon-xyz" {
  account_id = data.cloudflare_accounts.main.accounts[0].id
  zone       = vars.domain
}

resource "cloudflare_record" "salamon-xyz" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = vars.domain
  type    = "A"
  content = hcloud_server.icarus.ipv4_address
}

resource "cloudflare_record" "salamon-xyz-wildcard" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = "*"
  type    = "CNAME"
  content = cloudflare_record.salamon-xyz.name
}

resource "cloudflare_record" "aether" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = "aether.site"
  type    = "A"
  content = hcloud_server.icarus.ipv4_address
}

resource "cloudflare_record" "icarus" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = "icarus.aether.site"
  type    = "A"
  content = hcloud_server.icarus.ipv4_address
}
