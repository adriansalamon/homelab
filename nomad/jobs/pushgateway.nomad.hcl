job "prometheus-pushgateway" {
  type = "service"

  group "pushgateway" {
    count = 1

    network {
      mode = "cni/flannel"

      port "http" {
        to     = 9091
      }
    }

    task "pushgateway" {
      driver = "docker"

      config {
        image = "prom/pushgateway:latest"
        ports = ["http"]
        args = [
          "--persistence.file=/alloc/data/metrics"
        ]
      }

      resources {
        cpu    = 100
        memory = 256
      }

      template {
        data        = <<EOF
        DOMAIN="{{ key "config/domains/main" }}"
        EOF
        destination = "local/domain.env"
        env         = true
      }

      service {
        name = "prometheus-pushgateway"
        port = "http"
        tags = [
          "prometheus.scrape=true",
          "traefik.enable=true",
          "traefik.http.routers.prometheus-pushgateway.rule=Host(`push-metrics.local.${DOMAIN}`)",
        ]

        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
