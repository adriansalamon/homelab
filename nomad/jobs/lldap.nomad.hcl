job "lldap" {
  type = "service"

  group "lldap" {
    count = 2

    network {
      mode = "cni/flannel"

      port "http" {
        to = 17170
      }

      port "ldap" {
        to = 3890
      }
    }

    task "lldap" {
      driver = "docker"

      config {
        image = "lldap/lldap:latest-alpine"
        ports = ["http", "ldap"]
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
        LLDAP_LDAP_BASE_DN    = "dc=salamon,dc=xyz"
        LLDAP_LDAP_USER_EMAIL = "admin@${DOMAIN_ALT}"
        LLDAP_HTTP_URL        = "https://lldap.local.${DOMAIN}"
      }

      template {
        data = <<EOF
{{ with nomadVar "nomad/jobs/lldap" }}
LLDAP_JWT_SECRET = "{{ .jwt_secret }}"
LLDAP_KEY_SEED = "{{ .key_seed }}"
LLDAP_LDAP_USER_PASS = "{{ .user_password }}"
LLDAP_DATABASE_URL = "postgres://lldap:{{ .postgres_password }}@{{ range service "primary.homelab-cluster" }}{{ .Address }}:{{ .Port }}{{ end }}/lldap"
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
        port = "http"
        name = "lldap"

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
        port = "ldap"
        name = "lldap"

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
