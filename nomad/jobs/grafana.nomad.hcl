job "grafana" {
  group "grafana" {
    count = 1

    network {
      port "http" {
        static = 28364 #random ish
      }

      mode = "cni/nebula"
    }

    task "grafana" {
      driver = "docker"

      meta {
        nebula_roles = jsonencode(["grafana"])

        nebula_config = yamlencode({
          firewall = {
            outbound = [
              {
                port  = "any"
                proto = "any"
                host  = "any"
              }
            ]
            inbound = [
              {
                port  = "28364"
                proto = "tcp"
                group = "nomad-client"
              },
              {
                port  = "28364"
                proto = "tcp"
                group = "reverse-proxy"
              }
            ]
          }
        })
      }

      config {
        image = "grafana/grafana:12.4"
        ports = ["http"]
      }

      template {
        data        = <<EOF
{{ $domain := key "config/domains/main" }}
[analytics]
reporting_enabled = false

[users]
allow_sign_up = false

[server]
domain = grafana.local.{{ $domain }}
root_url = https://grafana.local.{{ $domain }}
enforce_domain = true
enable_gzip = true
http_addr = {{ env "NOMAD_ALLOC_IP_http" }}
http_port = {{ env "NOMAD_PORT_http" }}

[security]
disable_initial_admin_creation = true
cookie_secure = true
disable_gravatar = true
hide_version = true

[auth]
disable_login_form = true

[auth.generic_oauth]
enabled = true
name = Authelia
icon = signin
allow_sign_up = true
client_id = grafana
scopes = openid profile email groups
empty_scopes = false
login_attribute_path = preferred_username
groups_attribute_path = groups
auth_url = https://auth.{{ $domain }}/api/oidc/authorization
token_url = https://auth.{{ $domain }}/api/oidc/token
api_url = https://auth.{{ $domain }}/api/oidc/userinfo
use_pkce = true
# Allow mapping oidc roles to server admin
allow_assign_grafana_admin = true
role_attribute_path = contains(groups[*], 'server_admin') && 'GrafanaAdmin' || contains(groups[*], 'admin') && 'Admin' || contains(groups[*], 'editor') && 'Editor' || contains(groups[*], 'viewer') && 'Viewer'

[database]
type = postgres
host = {{ range service "primary.homelab-cluster" }}{{ .Address }}:{{ .Port }}{{ end }}
name = grafana
user = grafana
ssl_mode = disable
EOF
        destination = "${NOMAD_ALLOC_DIR}/grafana.ini"
      }

      template {
        data        = <<EOF
apiVersion: 1

datasources:
  - name: Victoria Metrics
    type: victoriametrics
    access: proxy
    url: http://lb-metrics.service.consul:{{ range service "lb-metrics" }}{{ .Port }}{{ end }}
    jsonData:
      timeInterval: "15s"

  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://lb-metrics.service.consul:{{ range service "lb-metrics" }}{{ .Port }}{{ end }}
    jsonData:
      timeInterval: "15s"
    isDefault: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki.service.consul:19832
    basicAuth: true
    basicAuthUser: "extra/homelab+grafana-loki-basic-auth-password"
    secureJsonData:
      basicAuthPassword: {{ with nomadVar "nomad/jobs/grafana" }}{{ .loki_basic_auth_password }}{{ end }}
EOF
        destination = "${NOMAD_ALLOC_DIR}/provisioning/datasources/sources.yaml"
      }

      template {
        data        = <<EOF
GF_PATHS_CONFIG="{{ env "NOMAD_ALLOC_DIR" }}/grafana.ini"
{{ with nomadVar "nomad/jobs/grafana" }}
GF_SECURITY_SECRET_KEY={{ .secret_key }}
GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET={{ .oidc_client_secret }}
GF_DATABASE_PASSWORD={{ .postgres_password }}
{{ end }}
DOMAIN="{{ key "config/domains/main" }}"
GF_PATHS_PROVISIONING="{{ env "NOMAD_ALLOC_DIR" }}/provisioning"
EOF
        env         = true
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name    = "grafana"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        check {
          type     = "http"
          path     = "/api/health"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.grafana.rule=Host(`grafana.local.${DOMAIN}`)",
        ]
      }
    }
  }
}
