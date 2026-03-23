job "vmauth" {
  group "vmauth" {
    count = 1

    network {
      port "http" {
        static = 28427
      }
      port "internal_http" {
        static = 28428
      }

      mode = "cni/nebula"
    }

    task "vmauth" {
      driver = "docker"

      meta {
        nebula_roles = jsonencode(["metrics-proxy"])

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
                port  = "28428"
                proto = "tcp"
                group = "nomad-client"
              },
              {
                port  = "28427"
                proto = "tcp"
                group = "metrics-ruler"
              },
              {
                port  = "28427"
                proto = "tcp"
                group = "grafana"
              }
            ]
          }
        })
      }

      config {
        image = "victoriametrics/vmauth:v1.138.0"
        ports = ["http", "internal_http"]
        args  = [
          "-auth.config=${NOMAD_ALLOC_DIR}/vmauth.yaml",
          "-httpListenAddr=${NOMAD_ALLOC_IP_http}:${NOMAD_PORT_http}",
          "-httpInternalListenAddr=${NOMAD_ALLOC_IP_internal_http}:${NOMAD_PORT_internal_http}",
        ]
      }

      template {
        data        = <<EOF
unauthorized_user:
  url_prefix:{{ range service "victoriametrics" }}
  - "http://{{ .Address }}:{{ .Port }}/"
{{ end }}
  load_balancing_policy: least_loaded
EOF
        destination = "${NOMAD_ALLOC_DIR}/vmauth.yaml"
      }

      resources {
        cpu    = 100
        memory = 64
      }

      service {
        name    = "lb-metrics"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"
      }

      service {
        port    = "internal_http"
        address = "${NOMAD_ALLOC_IP_internal_http}"

        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
