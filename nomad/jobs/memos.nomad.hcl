job "memos" {
  type = "service"

  group "memos" {
    count = 1

    network {
      mode = "cni/flannel"
      port "http" {
        to = 5230
      }
    }

    task "memos" {
      driver = "docker"

      service {
        name = "memos"
        port = "http"

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

      config {
        image = "neosmemo/memos:0.26.0"
        ports = ["http"]
      }

      resources {
        cpu    = 250
        memory = 512
      }

      template {
        data = <<EOF
DOMAIN="{{ key "config/domains/main" }}"
MEMOS_MODE=prod
MEMOS_PORT={{ env "NOMAD_PORT_http"}}
MEMOS_DRIVER=postgres
MEMOS_INSTANCE_URL=https://memos.{{ key "config/domains/main" }}
EOF
        destination = "local/config.env"
        env         = true
      }

      template {
        data = <<EOF
{{ with nomadVar "nomad/jobs/memos" }}
MEMOS_DSN="postgresql://memos:{{ .postgres_password }}@master.homelab-cluster.service.consul:5432/memos?sslmode=disable"
{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
        perms       = "0600"
      }
    }
  }
}
