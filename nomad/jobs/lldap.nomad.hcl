job "lldap" {
  type = "service"

  group "lldap" {
    count = 2

    network {
      mode = "cni/nebula"

      port "http" {
        static = 17170
      }

      port "ldap" {
        static = 3890
      }
    }

    task "lldap" {
      driver = "docker"

      vault {}

      config {
        image = "lldap/lldap:2026-03-04-alpine"
        ports = ["http", "ldap"]
      }

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
            inbound = concat([for group in ["reverse-proxy", "nomad-client"] : {
              port  = "17170"
              proto = "tcp"
              group = group
              }], [for group in ["ldap-client", "nomad-client"] : {
              port  = "3890"
              proto = "tcp"
              group = group
            }])
          }
        })
      }

      template {
        data        = <<EOF
          DOMAIN="{{ key "config/domains/main" }}"
          DOMAIN_ALT="{{ key "config/domains/alt" }}"
          EOF
        destination = "local/domain.env"
        env         = true
        change_mode = "noop"
      }

      env {
        LLDAP_LDAP_HOST = "${NOMAD_ALLOC_IP_ldap}"
        LLDAP_LDAP_PORT = "${NOMAD_PORT_ldap}"

        LLDAP_HTTP_HOST = "${NOMAD_ALLOC_IP_http}"
        LLDAP_HTTP_PORT = "${NOMAD_PORT_http}"

        LLDAP_LDAP_BASE_DN    = "dc=salamon,dc=xyz"
        LLDAP_LDAP_USER_EMAIL = "admin@${DOMAIN_ALT}"
        LLDAP_HTTP_URL        = "https://lldap.local.${DOMAIN}"
      }

      template {
        data = <<EOF
{{ with secret "secret/data/default/lldap" }}
LLDAP_JWT_SECRET = "{{ .Data.data.jwt_secret }}"
LLDAP_KEY_SEED = "{{ .Data.data.key_seed }}"
LLDAP_LDAP_USER_PASS = "{{ .Data.data.user_password }}"
LLDAP_DATABASE_URL = "postgres://lldap:{{ .Data.data.postgres_password }}@{{ range service "primary.homelab-cluster" }}{{ .Address }}:{{ .Port }}{{ end }}/lldap"
{{ end }}
EOF

        destination = "secrets/lldap.env"
        env         = true
      }

      resources {
        cpu    = 100
        memory = 256
      }

      service {
        port    = "http"
        name    = "lldap"
        address = "${NOMAD_ALLOC_IP_http}"

        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "http",
          "traefik.enable=true",
          "traefik.http.routers.lldap.rule=Host(`lldap.local.${DOMAIN}`)",
        ]
      }

      service {
        port    = "ldap"
        name    = "lldap"
        address = "${NOMAD_ALLOC_IP_ldap}"

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }

        tags = ["ldap"]
      }
    }
  }
}
