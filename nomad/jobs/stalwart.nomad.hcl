job "stalwart" {
  type = "service"

  group "stalwart" {
    count = 1

    network {
      mode = "cni/flannel"

      port "smtp" { to = 25 }
      port "submission" { to = 587 }
      port "imaps" { to = 993 }
      port "http" { to = 8080 }
    }

    task "stalwart" {
      driver = "docker"

      config {
        image = "stalwartlabs/stalwart:v0.15.5"
        ports = ["submission", "imaps", "http"]

        volumes = [
          "local/config.toml:/opt/stalwart/etc/config.toml",
        ]
      }

      template {
        destination = "local/config.toml"
        data        = <<EOF
{{ $domain := key "config/domains/main" }}
[server]
hostname = "mail.{{ $domain }}"

[server.listener."smtp"]
bind = "[::]:25"
protocol = "smtp"
proxy.override = true
proxy.trusted-networks = ["10.64.32.0/19"]

[server.listener."submission"]
bind = "[::]:587"
protocol = "smtp"
tls.implicit = false
proxy.override = true
proxy.trusted-networks = ["10.64.32.0/19"]


[server.listener."imap"]
bind = "[::]:143"
protocol = "imap"

[server.listener."imaps"]
bind = "[::]:993"
protocol = "imap"
tls.implicit = true
proxy.override = true
proxy.trusted-networks = ["10.64.32.0/19"]


[server.listener."management"]
bind = "[::]:8080"
protocol = "http"
tls.implicit = false

# ===================
# Storage: S3 (SeaweedFS)
# ===================
[store."s3"]
type = "s3"
bucket = "stalwart-mail"
region = "us-east-1"
endpoint = "https://s3.local.{{ $domain }}"
access-key = "stalwart-mail"
secret-key = "{{ with nomadVar "nomad/jobs/stalwart" }}{{ .s3_secret_key }}{{ end }}"


# ===================
# Database: Postgres
# ===================
[store."postgres"]
type = "postgresql"
{{ range service "primary.homelab-cluster" }}
host = "{{ .Address }}"
port = "{{ .Port }}"
{{ end }}
database = "stalwart"
user = "stalwart"
password = "{{ with nomadVar "nomad/jobs/stalwart" }}{{ .postgres_password }}{{ end }}"

# ===================
# Assign stores
# ===================
[storage]
data = "postgres"
blob = "s3"
lookup = "postgres"
fts = "postgres"
directory = "authelia"

# ===================
# TLS (Let's Encrypt)
# ===================
[acme."letsencrypt"]
directory = "https://acme-v02.api.letsencrypt.org/directory"
contact = ["mailto:admin@{{ $domain }}"]
domains = ["mail.{{ $domain }}"]
challenge = "dns-01"
renew-before = "30d"
provider = "cloudflare"
secret = "{{ with nomadVar "nomad/jobs/stalwart" }}{{ .cloudflare_dns_api_token }}{{ end }}"

[certificate."default"]
acme = "letsencrypt"
subjects = ["mail.{{ $domain }}"]
default = true

# ===================
# OIDC directory
# ===================
[directory."authelia"]
type = "oidc"
timeout = "15s"
endpoint.url = "https://auth.{{ $domain }}/api/oidc/userinfo"
endpoint.method = "userinfo"
fields.email = "email"
fields.username = "preferred_username"
fields.full-name = "name"

# ===================
# Admin
# ===================
[authentication.fallback-admin]
user = "admin"
secret = "{{ with nomadVar "nomad/jobs/stalwart" }}{{ .admin_password }}{{ end }}"
          EOF
      }

      resources {
        cpu    = 500
        memory = 512
      }

      template {
        data        = <<EOF
        DOMAIN="{{ key "config/domains/main" }}"
        EOF
        destination = "local/domain.env"
        env         = true
      }


      service {
        name = "stalwart-smtp"
        port = "smtp"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.tcp.routers.smtp.rule=HostSNI(`*`)",
          "traefik.tcp.routers.smtp.entrypoints=smtp",
          "traefik.tcp.services.stalwart-smtp.loadBalancer.serversTransport=proxy@file"
        ]
      }

      service {
        name = "stalwart-submission"
        port = "submission"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.tcp.routers.submission.rule=HostSNI(`*`)",
          "traefik.tcp.routers.submission.entrypoints=submission",
          "traefik.tcp.services.stalwart-submission.loadBalancer.serversTransport=proxy@file"
        ]
      }

      service {
        name = "stalwart-imaps"
        port = "imaps"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.tcp.routers.imaps.rule=HostSNI(`*`)",
          "traefik.tcp.routers.imaps.entrypoints=imaps",
          "traefik.tcp.services.stalwart-imaps.loadBalancer.serversTransport=proxy@file"
        ]
      }

      service {
        name = "stalwart-http"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.stalwart.rule=Host(`mail.${DOMAIN}`)",
          "traefik.http.routers.stalwart.entrypoints=websecure"
        ]

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
