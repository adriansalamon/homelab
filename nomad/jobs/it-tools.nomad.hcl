job "it-tools" {
  group "it-tools" {

    network {
      port "http" {
        static = 26054
      }

      mode = "cni/nebula"
    }

    task "it-tools" {
      driver = "docker"

      config {
        image = "sharevb/it-tools:2026.1.4"
        ports = ["http"]
      }

      env {
        PORT = "${NOMAD_ALLOC_PORT_http}"
      }

      meta {
        nebula_roles = jsonencode(["test"])

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
                port  = 26054
                proto = "tcp"
                group = "reverse-proxy"
              }
            ]
          }
        })
      }

      template {
        data        = <<EOF
        DOMAIN="{{ key "config/domains/main" }}"
        EOF
        destination = "local/domain.env"
        env         = true
      }


      service {
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.it-tools.rule=Host(`it-tools.local.${DOMAIN}`)",
        ]
      }
    }
  }
}
