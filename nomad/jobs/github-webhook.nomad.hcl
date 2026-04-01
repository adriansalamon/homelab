job "github-webhook" {
  group "webhook" {
    count = 1

    network {
      port "http" {
        static = 28765 # Choose an unused port
      }

      mode = "cni/nebula"
    }

    task "webhook" {
      driver = "docker"

      identity {
        env = true # Get NOMAD_TOKEN from workload identity
      }

      meta {
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
                port  = "28765"
                proto = "tcp"
                group = "reverse-proxy"
              }
            ]
          }
        })
      }

      config {
        image = "ghcr.io/adriansalamon/github-runner-webhook:self-hosted-runner-4b09750"

        ports = ["http"]
      }

      env {
        # Customize these for your GitHub repo
        GITHUB_ORG         = "adriansalamon"
        GITHUB_REPO        = "homelab"
        NOMAD_JOB_TEMPLATE = "github-runner"
        ADDR               = ":${NOMAD_PORT_http}"
        NOMAD_ADDR         = "${NOMAD_UNIX_ADDR}"
      }

      # Get secrets from Nomad variables
      template {
        data        = <<EOF
{{ $domain := key "config/domains/main" }}
{{ with nomadVar "nomad/jobs/github-webhook" }}
GITHUB_WEBHOOK_SECRET={{ .webhook_secret }}
GITHUB_PAT={{ .pat }}
{{ end }}
DOMAIN={{ $domain }}
EOF
        env         = true
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name    = "github-webhook"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.http.routers.github-webhook.rule=Host(`github-runner-webhook.${DOMAIN}`)",
          "traefik.http.routers.github-webhook.entrypoints=websecure",
        ]
      }
    }
  }
}
