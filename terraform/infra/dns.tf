resource "cloudflare_zone" "salamon-xyz" {
  name = var.domain
  account = {
    id = data.cloudflare_accounts.main.result[0].id
  }
}

resource "cloudflare_zone" "me" {
  name = var.domain_me
  account = {
    id = data.cloudflare_accounts.main.result[0].id
  }
}

resource "cloudflare_dns_record" "salamon-xyz" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = var.domain
  type    = "A"
  content = hcloud_server.icarus.ipv4_address
  ttl     = 1
}


resource "cloudflare_dns_record" "salamon-xyz-wildcard" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = "*"
  type    = "CNAME"
  content = cloudflare_dns_record.salamon-xyz.name
  ttl     = 1
}

resource "cloudflare_dns_record" "aether" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = "aether.site"
  type    = "A"
  content = hcloud_server.icarus.ipv4_address
  ttl     = 1
}

resource "cloudflare_dns_record" "icarus" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = "icarus.aether.site"
  type    = "A"
  content = hcloud_server.icarus.ipv4_address
  ttl     = 1
}


resource "cloudflare_dns_record" "mail" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = "mail"
  type    = "CNAME"
  content = cloudflare_dns_record.salamon-xyz.name
  ttl     = 1
}

resource "cloudflare_dns_record" "me" {
  zone_id = cloudflare_zone.me.id
  name    = var.domain_me
  type    = "A"
  content = hcloud_server.icarus.ipv4_address
  proxied = true
  ttl     = 1
}
