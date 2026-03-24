job "prometheus" {
  group "prometheus" {
    count = 1

    network {
      port "http" {
        static = 9094
      }

      mode = "cni/nebula"
    }


    task "prometheus" {
      driver = "docker"

      meta {
        nebula_roles = jsonencode(["metrics-collector", "consul-client", "prometheus"])


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
                port  = "9094"
                proto = "tcp"
                group = "nomad-client"
              },
              {
                port  = "9094"
                proto = "tcp"
                group = "reverse-proxy"
              },
              {
                port  = "9094"
                proto = "tcp"
                group = "metrics-ruler"
              }
            ]
          }
        })
      }

      config {
        image = "prom/prometheus:v3.10.0-distroless"
        ports = ["http"]
        args = [
          "--config.file=${NOMAD_ALLOC_DIR}/prometheus.yaml",
          "--storage.tsdb.path=/tmp/prometheus",
          "--storage.tsdb.retention.time=2h",
          "--web.listen-address=${NOMAD_ALLOC_IP_http}:${NOMAD_PORT_http}",
          "--web.enable-remote-write-receiver",
        ]
      }

      template {
        data        = <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

remote_write:
{{ range service "victoriametrics"}}
  - url: "http://{{ .Address }}:{{ .Port }}/api/v1/write"
{{ end }}

storage:
  tsdb:
    out_of_order_time_window: 24h # for vmalert to write to

scrape_configs:
  - job_name: "consul"
    consul_sd_configs:
      - server: "consul.service.consul:8500"
        tags:
          - "prometheus.scrape=true"
    tls_config:
      insecure_skip_verify: true
    relabel_configs:
      - source_labels: [__meta_consul_node]
        replacement: $1
        target_label: instance
      - source_labels: [__meta_consul_tags]
        regex: ".*,prometheus\\.path=([^,]*),.*"
        replacement: $1
        target_label: __metrics_path__
      - source_labels: [__meta_consul_tags]
        regex: ".*,prometheus\\.scheme=([^,]*),.*"
        target_label: __scheme__
        replacement: $1
      - source_labels: [__meta_consul_tags]
        regex: ".*,prometheus\\.query\\.format=([^,]*),.*"
        target_label: __param_format
        replacement: $1
EOF
        destination = "${NOMAD_ALLOC_DIR}/prometheus.yaml"
      }

      resources {
        cpu    = 200
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
        name    = "prometheus"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.external=false",
          "traefik.http.routers.prometheus.rule=Host(`prometheus.local.${DOMAIN}`)",
          "traefik.http.routers.prometheus-health.rule=Host(`prometheus.local.${DOMAIN}`) && Path(`/-/healthy`)",
          "traefik.http.routers.prometheus.middlewares=authelia",
        ]
      }
    }
  }
}
