job "kv-proxy" {
  group "kv-proxy" {
    count = 1

    network {
      port "http" {
        static = 1072
      }

      mode = "cni/nebula"
    }

    task "kv-proxy" {
      driver = "docker"

      env {
        CONSUL_HTTP_ADDR = "http://consul.service.consul:8500"
        ADDR             = "${NOMAD_ALLOC_IP_http}:${NOMAD_PORT_http}"
      }

      config {
        image = "ghcr.io/adriansalamon/consul-kv-proxy:main-e5c6d46"
        ports = ["http"]
      }

      meta {
        nebula_roles = jsonencode(["consul-client"])

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
              port  = "1072"
              proto = "tcp"
              group = group
            }]
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
        name    = "kv-proxy"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.http.routers.kv-proxy.rule=Host(`kv-proxy.${DOMAIN}`)",
        ]
      }
    }
  }
}
