job "memos" {
  type = "service"

  group "memos" {
    count = 1

    network {
      mode = "cni/nebula"
      port "http" {
        static = 5230
      }
    }

    task "memos" {
      driver = "docker"

      config {
        image = "neosmemo/memos:0.26.2"
        ports = ["http"]
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
            inbound = [for group in ["reverse-proxy", "nomad-client"] : {
              port  = "5230"
              proto = "tcp"
              group = group
            }]
          }
        })
      }

      template {
        data        = <<EOF
DOMAIN="{{ key "config/domains/main" }}"
MEMOS_MODE=prod
MEMOS_ADDR={{ env "NOMAD_ALLOC_IP_http" }}
MEMOS_PORT={{ env "NOMAD_PORT_http"}}
MEMOS_DRIVER=postgres
MEMOS_INSTANCE_URL=https://memos.{{ key "config/domains/main" }}
EOF
        destination = "local/config.env"
        env         = true
      }

      template {
        data        = <<EOF
{{ with nomadVar "nomad/jobs/memos" }}
MEMOS_DSN="postgresql://memos:{{ .postgres_password }}@master.homelab-cluster.service.consul:5432/memos?sslmode=disable"
{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
        perms       = "0600"
      }

      service {
        name    = "memos"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.http.routers.memos.rule=Host(`memos.${DOMAIN}`)",
          "traefik.http.routers.memos.entrypoints=websecure"
        ]

        check {
          type     = "tcp"
          port     = "http"
          interval = "30s"
          timeout  = "10s"
        }
      }

      resources {
        cpu    = 250
        memory = 512
      }
    }
  }
}
