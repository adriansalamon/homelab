job "kv-proxy" {
  group "kv-proxy" {
    count = 1

    network {
      port "http" {
        to = 8080
      }

      mode = "cni/flannel"
    }

    task "kv-proxy" {
      driver = "docker"

      env {
        CONSUL_HTTP_ADDR = "http://consul.service.consul:8500"
      }

      config {
        image = "ghcr.io/adriansalamon/consul-kv-proxy:main-8ed8852"
        ports = ["http"]
      }


      template {
        data        = <<EOF
        DOMAIN="{{ key "config/domains/main" }}"
        EOF
        destination = "local/domain.env"
        env         = true
      }

      service {
        name = "kv-proxy"
        port = "http"

        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.kv-proxy.rule=Host(`kv-proxy.${DOMAIN}`)",
        ]
      }
    }
  }
}
