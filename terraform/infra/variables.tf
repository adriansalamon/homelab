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

variable "domain" {
  type        = string
  description = "Domain name"
}

variable "domain_me" {
  type = string
}
