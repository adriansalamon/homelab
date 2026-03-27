job "opengist" {
  type = "service"

  group "opengist" {
    count = 1

    network {
      mode = "cni/nebula"
      port "http" {
        static = 13487
      }
    }

    # CSI volume for git repositories and data, did not work well on seaweedfs
    volume "opengist-data" {
      type            = "host"
      source          = "opengist-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "single-node-single-writer"
    }

    task "opengist" {
      driver = "docker"

      volume_mount {
        volume      = "opengist-data"
        destination = "/opengist"
        read_only   = false
      }

      config {
        image = "ghcr.io/thomiceli/opengist:1.12"
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
              port  = "13487"
              proto = "tcp"
              group = group
            }]
          }
        })
      }

      template {
        data        = <<EOF
DOMAIN="{{ key "config/domains/main" }}"
OG_EXTERNAL_URL=https://gist.{{ key "config/domains/main" }}
OG_LOG_LEVEL=info
OG_HTTP_HOST={{ env "NOMAD_ALLOC_IP_http" }}
OG_HTTP_PORT={{ env "NOMAD_PORT_http" }}
OG_SSH_GIT_ENABLED=false
EOF
        destination = "local/config.env"
        env         = true
      }

      template {
        data        = <<EOF
{{ with nomadVar "nomad/jobs/opengist" }}
OG_DB_URI=postgres://opengist:{{ .postgres_password }}@master.homelab-cluster.service.consul:5432/opengist
OG_OIDC_PROVIDER_NAME=authelia
OG_OIDC_CLIENT_KEY=opengist
OG_OIDC_SECRET={{ .oidc_client_secret }}
OG_OIDC_DISCOVERY_URL=https://auth.{{ key "config/domains/main" }}/.well-known/openid-configuration
{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
        perms       = "0600"
      }

      service {
        name    = "opengist-http"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          #"traefik.external=true",
          "traefik.http.routers.opengist.rule=Host(`gist.${DOMAIN}`)",
          "traefik.http.routers.opengist.entrypoints=websecure"
        ]

        check {
          type     = "http"
          path     = "/healthcheck"
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
