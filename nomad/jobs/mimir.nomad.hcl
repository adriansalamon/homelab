job "mimir" {

  update {
     max_parallel      = 1
     health_check      = "checks"
     healthy_deadline  = "10m"
     progress_deadline = "20m"
     stagger           = "30s"
   }

  group "mimir" {
    count = 1

    ephemeral_disk {
      size    = 1024 # MB
      migrate = true
      sticky  = true
    }

    network {
      port "http" {
        static = 9009
      }

      mode = "cni/nebula"
    }

    task "mimir" {
      driver = "docker"

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
                port  = "9009"
                proto = "tcp"
                group = "nomad-client"
              },
              {
                port  = "9009"
                proto = "tcp"
                group = "reverse-proxy"
              },
              {
                port  = "9009"
                proto = "tcp"
                group = "prometheus"
              },
              {
                port  = "9009"
                proto = "tcp"
                host  = "zeus-prometheus"
              },
              {
                port  = "9009"
                proto = "tcp"
                host  = "zeus-grafana"
              }
            ]
          }
        })
      }

      config {
        image = "grafana/mimir:3.0.4"
        ports = ["http"]
        args  = ["-config.file=${NOMAD_ALLOC_DIR}/mimir.yaml"]
      }

      template {
        data        = <<EOF
multitenancy_enabled: false

common:
  storage:
    backend: s3
    s3:
      endpoint:          "s3.local.{{ key "config/domains/main" }}"
      access_key_id:     "mimir"
      secret_access_key: "{{ with nomadVar "nomad/jobs/mimir" }}{{ .s3_secret_key }}{{ end }}"
      bucket_name:       "mimir-storage"

blocks_storage:
  backend: s3
  storage_prefix: "blocks"
  tsdb:
    flush_blocks_on_shutdown: true
    dir: /alloc/data/tsdb
  bucket_store:
    sync_dir: /alloc/data/tsdb-sync

ingester:
  ring:
    replication_factor: 1

store_gateway:
  sharding_ring:
    replication_factor: 1

compactor:
  data_dir: /alloc/data/compactor

limits:
  compactor_block_upload_enabled: true

ruler_storage:
  backend: s3
  storage_prefix: "ruler"


alertmanager_storage:
  backend: s3
  storage_prefix: "alertmanager"

server:
  http_listen_address: {{ env "NOMAD_ALLOC_IP_http" }}
  http_listen_port: {{ env "NOMAD_PORT_http" }}

usage_stats:
  enabled: false
EOF
        destination = "${NOMAD_ALLOC_DIR}/mimir.yaml"
      }

      resources {
        cpu    = 256
        memory = 1024
      }

      template {
        data        = <<EOF
        DOMAIN="{{ key "config/domains/main" }}"
        EOF
        destination = "local/domain.env"
        env         = true
      }

      service {
        name    = "mimir"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        check {
          type     = "http"
          path     = "/ready"
          interval = "10s"
          timeout  = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.external=false",
          "traefik.http.routers.mimir.rule=Host(`mimir.local.${DOMAIN}`)",
          "traefik.http.routers.mimir.middlewares=authelia"
        ]
      }
    }
  }
}
