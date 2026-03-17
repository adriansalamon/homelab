job "stalwart" {
  type = "service"

  group "stalwart" {
    count = 1

    network {
      mode = "cni/nebula"

      port "smtp" { static = 25 }
      port "submission" { static = 587 }
      port "imaps" { static = 993 }
      port "http" { static = 8083 }
      port "management" { static = 9191 }
    }

    task "stalwart" {
      driver = "docker"

      meta {
        nebula_roles = jsonencode(["postgres-client"])

        nebula_config = yamlencode({
          firewall = {
            outbound = [
              {
                port  = "any"
                proto = "any"
                host  = "any"
              }
            ]
            inbound = concat(
              flatten([
                for group, ports in {
                  "reverse-proxy" = ["25", "587", "993", "8083", "9191"]
                  "nomad-client"  = ["8083", "9191"]
                  } : [
                  for port in ports : {
                    group = group
                    proto = "tcp"
                    port  = port
                  }
                ]
              ]),
              [
                {
                  host  = "zeus-prometheus" # TODO: migrate to a group
                  proto = "tcp"
                  port  = "9191"
                },
                {
                  group = "prometheus"
                  proto = "tcp"
                  port  = "9191"
                }
              ]
            )
          }
        })
      }

      config {
        image = "stalwartlabs/stalwart:v0.15.5"
        ports = ["submission", "imaps", "http", "management"]

        volumes = [
          "local/config.toml:/opt/stalwart/etc/config.toml",
        ]
      }

      template {
        destination = "local/config.toml"
        data        = <<EOF
{{ $domain := key "config/domains/main" }}
[config]
local-keys = [ "store.*", "directory.*", "tracer.*", "!server.blocked-ip.*", "!server.allowed-ip.*", "server.*",
               "authentication.fallback-admin.*", "cluster.*",   "config.local-keys.*",
               "storage.data", "storage.blob", "storage.lookup", "storage.fts", "storage.directory", "certificate.*",
               "metrics.prometheus.*", "http.*", "!acme.letsencrypt.account-key", "!acme.letsencrypt.cert", "acme.*" ]

[server]
hostname = "mail.{{ $domain }}"

[server.listener."smtp"]
bind = "{{ env "NOMAD_ALLOC_IP_smtp" }}:25"
protocol = "smtp"
proxy.override = true
proxy.trusted-networks = ["10.64.32.0/19"]

[server.listener."submission"]
bind = "{{ env "NOMAD_ALLOC_IP_smtp" }}:587"
protocol = "smtp"
tls.implicit = false
proxy.override = true
proxy.trusted-networks = ["10.64.32.0/19"]


[server.listener."imap"]
bind = "{{ env "NOMAD_ALLOC_IP_smtp" }}:143"
protocol = "imap"

[server.listener."imaps"]
bind = "{{ env "NOMAD_ALLOC_IP_smtp" }}:993"
protocol = "imap"
tls.implicit = true
proxy.override = true
proxy.trusted-networks = ["10.64.32.0/19"]


[server.listener."management"]
bind = "{{ env "NOMAD_ALLOC_IP_smtp" }}:9191"
protocol = "http"
tls.implicit = false

[server.listener."public-http"]
bind = "{{ env "NOMAD_ALLOC_IP_smtp" }}:8083"
protocol = "http"
tls.implicit = false

[http]
allowed-endpoint = [ { if = "listener == 'management' || contains( [ 'jmap', 'robots.txt', '.well-known', 'dav', 'calendar', 'auth' ], split( url_path, '/' )[1] )",
                       then = "200" },
                     { else = "403" } ]
url = "'https://' + config_get('server.hostname')"

[metrics.prometheus]
enable = true

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
        cpu    = 3000
        memory = 500
      }

      template {
        data        = <<EOF
        DOMAIN="{{ key "config/domains/main" }}"
        EOF
        destination = "local/domain.env"
        env         = true
      }


      service {
        name    = "stalwart-smtp"
        port    = "smtp"
        address = "${NOMAD_ALLOC_IP_smtp}"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.tcp.routers.smtp.rule=HostSNI(`*`)",
          "traefik.tcp.routers.smtp.entrypoints=smtp",
          "traefik.tcp.services.stalwart-smtp.loadBalancer.serversTransport=proxy@file"
        ]
      }

      service {
        name    = "stalwart-submission"
        port    = "submission"
        address = "${NOMAD_ALLOC_IP_smtp}"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.tcp.routers.submission.rule=HostSNI(`*`)",
          "traefik.tcp.routers.submission.entrypoints=submission",
          "traefik.tcp.services.stalwart-submission.loadBalancer.serversTransport=proxy@file"
        ]
      }

      service {
        name    = "stalwart-imaps"
        port    = "imaps"
        address = "${NOMAD_ALLOC_IP_smtp}"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.tcp.routers.imaps.rule=HostSNI(`*`)",
          "traefik.tcp.routers.imaps.entrypoints=imaps",
          "traefik.tcp.services.stalwart-imaps.loadBalancer.serversTransport=proxy@file"
        ]
      }

      service {
        name    = "stalwart-http"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_smtp}"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.http.routers.stalwart.rule=Host(`mail.${DOMAIN}`)",
          "traefik.http.routers.stalwart.entrypoints=websecure"
        ]

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }



      service {
        name    = "stalwart-management"
        port    = "management"
        address = "${NOMAD_ALLOC_IP_smtp}"

        tags = [
          "traefik.enable=true",
          # Hack (?) to prioritize this over the stalwart-http service, since the rule is longer
          "traefik.http.routers.stalwart-mgmt.rule=Host(`mail.${DOMAIN}`) && PathRegexp(`.*`)",
          "traefik.http.routers.stalwart-mgmt.entrypoints=websecure",
          # metrics
          "prometheus.scrape=true",
          "prometheus.path=/metrics/prometheus"
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
