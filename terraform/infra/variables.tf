variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token"
  sensitive   = true
}

variable "cloudflare_email" {
  type        = string
  description = "Cloudflare email"
}

variable "hcloud_token" {
  sensitive = true
}

variable "consul_bootstrap_token" {
  type        = string
  description = "Consul bootstrap token"
  sensitive   = true
}

variable "domain" {
  type        = string
  description = "Domain name"
}

variable "nomad_bootstrap_token" {
  type        = string
  description = "Nomad bootstrap token"
}

variable "nomad_oidc_client_secret" {
  type      = string
  sensitive = true
}

variable "nomad_url" {
  type = string
}

variable "authelia_oidc_client_secret" {
  description = "The OIDC client secret configured in Authelia"
  type        = string
  sensitive   = true
}
