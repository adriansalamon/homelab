job "homepage" {
  group "homepage" {
    count = 1

    network {
      port "http" {
        static = 3000
      }

      mode = "cni/nebula"
    }

    task "homepage" {
      driver = "docker"

      env {
        CONSUL_HTTP_ADDR = "http://consul.service.consul:8500"
        PORT             = "${NOMAD_PORT_http}"
        HOST             = "${NOMAD_ALLOC_IP_http}"
      }

      config {
        image = "ghcr.io/adriansalamon/homepage:main-e4f43ad"
        ports = ["http"]
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
                port  = "3000"
                proto = "tcp"
                group = "reverse-proxy"
              }
            ]
          }
        })
      }

      template {
        data        = <<EOF
        {{ range sprig_list "athena" "charon" "demeter" "hermes" "icarus" "orpheus" "penelope" "pythia" "zeus" }}
        [[nodes]]
        name = "{{ . }}"
        {{ end }}
        EOF
        destination = "${NOMAD_ALLOC_DIR}/nodes.toml"
      }

      template {
        data        = <<EOF
        PUBLIC_DOMAIN="{{ key "config/domains/main" }}"
        PUBLIC_LOCAL_DOMAIN="local.{{ key "config/domains/main" }}"
        JELLYFIN_URL="https://jellyfin.{{ key "config/domains/main" }}"
        CONSUL_HTTP_ADDR="http://consul.service.consul:8500"
        NODES_FILE={{ env "NOMAD_ALLOC_DIR" }}/nodes.toml
        EOF
        destination = "${NOMAD_ALLOC_DIR}/homepage.env"
        env         = true
      }

      template {
        data        = <<EOF
        {{ with nomadVar "nomad/jobs/homepage" }}
        CONSUL_HTTP_TOKEN={{ .consul_http_token }}
        JELLYFIN_TOKEN={{ .jellyfin_token }}
        {{ end }}
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name    = "homepage"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.homepage.rule=Host(`home.${PUBLIC_DOMAIN}`) || Host(`home.local.${PUBLIC_DOMAIN}`)",
          "traefik.http.routers.homepage.middlewares=authelia"
        ]
      }
    }
  }
}
