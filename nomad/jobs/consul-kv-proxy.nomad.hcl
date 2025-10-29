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
        image = "ghcr.io/adriansalamon/consul-kv-proxy:25b4c6c1"
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

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.kv-proxy.rule=Host(`kv-proxy.${DOMAIN}`)",
        ]
      }

    }
  }
}
