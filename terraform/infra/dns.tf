resource "cloudflare_zone" "salamon-xyz" {
  name = var.domain
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


resource "cloudflare_dns_record" "mx" {
  zone_id  = cloudflare_zone.salamon-xyz.id
  name     = var.domain
  type     = "MX"
  content  = "mail.${var.domain}"
  priority = 10
  ttl      = 1
}

resource "cloudflare_dns_record" "mail" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = "mail"
  type    = "A"
  content = hcloud_server.icarus.ipv4_address
  proxied = false
  ttl     = 1
}


resource "cloudflare_dns_record" "spf" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = var.domain
  type    = "TXT"
  content = "v=spf1 a:mail.${var.domain} include:amazonses.com ~all"
  ttl     = 1
}

resource "cloudflare_dns_record" "dmarc" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = "_dmarc"
  type    = "TXT"
  content = "v=DMARC1; p=none; rua=mailto:postmaster@${var.domain}"
  ttl     = 1
}

resource "cloudflare_dns_record" "dkim_1" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = "202603e._domainkey"
  type    = "TXT"
  content = "v=DKIM1; k=ed25519; h=sha256; p=W+stw6RL5+14hwio1pSTSuRFjTu/TAsKDKPN40m/Rss="
  ttl     = 1
}


resource "cloudflare_dns_record" "dkim_2" {
  zone_id = cloudflare_zone.salamon-xyz.id
  name    = "202603r._domainkey"
  type    = "TXT"
  content = "v=DKIM1; k=rsa; h=sha256; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAx1QoJCfgPKtDhKn2//33J10PUNT9jOiBO/zxjpSXhvFRk29rcANe7IxTTd5tLlx/4MMvok7nylZp8ChsrFQ35nfBwwneJ6MsWmk/4furE4aBe2M4NDNuOfC9+tQBbpjFgKkhC2ghHO7y1Ii/2RPwFLCyDrcLPAANVqBqYYeJ6abB0Sm4HlsdPVWTeT5gX1xhk/7Pzywn1lV4DRToaR1ZsHheTSSI9mPHRrbrt3vF1ZmPyGN/c6dLsUfNrqX/yHplUpRXyotTRP6siFnfuXELkJg67wOG5j+vnnilgwn3rMwDvWywNYgs9q3W3prwNTEAQUpp18A8Ggu+Hs4sdkAoLQIDAQAB"
  ttl     = 1
}
