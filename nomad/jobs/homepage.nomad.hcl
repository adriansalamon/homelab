job "homepage" {
  group "homepage" {
    count = 1

    network {
      port "http" {
        to = 3000
      }

      mode = "cni/flannel"
    }

    task "homepage" {
      driver = "docker"

      env {
        CONSUL_HTTP_ADDR = "http://consul.service.consul:8500"
      }

      config {
        image = "ghcr.io/adriansalamon/consul-kv-proxy:25b4c6c1"
        ports = ["http"]
      }


      template {
        data        = <<EOF
        {{ range $name := var.nodes }}
        [[nodes]]
        name = "{{ $name }}"
        {{ end }}
        EOF
        destination = "local/nodes.toml"
      }

      template {
        data        = <<EOF
        PUBLIC_DOMAIN="{{ key "config/domains/main" }}"
        PUBLIC_LOCAL_DOMAIN="local.{{ key "config/domains/main" }}"
        JELLYFIN_URL="https://jellyfin.{{ key "config/domains/main" }}"
        CONSUL_HTTP_ADDR="http://consul.service.consul:8500"
        NODES_FILE=local/nodes.toml
        EOF
        destination = "local/homepage.env"
        env         = true
      }

      template {
        data        = <<EOF
        {{ with nomadVars "nomad/jobs/homepage" }}
        CONSUL_HTTP_TOKEN={{ .consul_http_token }}
        JELLYFIN_TOKEN={{ .jellyfin_token }}
        {{ end }}
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        mode        = "0600"
        env         = true
      }

      service {
        name = "kv-proxy"
        port = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.kv-proxy.rule=Host(`kv-proxy.${PUBLIC_DOMAIN}`)",
        ]
      }
    }
  }
}

variable "nodes" {
  type = list(string)
  default = ["athena", "charon", "demeter", "hermes", "icarus", "orpheus", "penelope", "pythia", "zeus"]
}
