job "prometheus-pushgateway" {
  type = "service"

  group "pushgateway" {
    count = 1

    network {
      mode = "cni/nebula"

      port "http" {
        static = 9091
      }
    }

    task "pushgateway" {
      driver = "docker"

      config {
        image = "prom/pushgateway:v1.11.2"
        ports = ["http"]
        args = [
          "--persistence.file=/alloc/data/metrics",
          "--web.listen-address=${NOMAD_ALLOC_IP_http}:${NOMAD_PORT_http}"
        ]
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
            inbound = concat([for group in ["reverse-proxy", "nomad-client"] : {
              port  = "9091"
              proto = "tcp"
              group = group
              }], [
              {
                group = "prometheus"
                proto = "tcp"
                port  = "9091"
              }
            ])
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
        name    = "prometheus-pushgateway"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

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

      resources {
        cpu    = 100
        memory = 256
      }
    }
  }
}
