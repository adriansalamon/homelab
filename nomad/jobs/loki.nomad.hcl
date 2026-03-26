job "loki" {
  group "loki" {
    count = 1

    ephemeral_disk {
      size    = 500 # for WAL
      sticky  = true
      migrate = true
    }

    network {
      port "http" {
        static = 19832
      }

      mode = "cni/nebula"
    }

    task "loki" {
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
              # Only nginx sidecar talks to loki directly
              {
                port  = 19832
                proto = "tcp"
                host  = "any" # todo: restrict with groups also
              }
            ]
          }
        })
      }

      config {
        image = "grafana/loki:3.6"
        args  = ["-config.file=${NOMAD_ALLOC_DIR}/loki.yaml", "-config.expand-env"]
      }


      template {
        data            = <<EOF
S3_SECRET_KEY={{ with nomadVar "nomad/jobs/loki" }}{{ .s3_secret_key }}{{ end }}
EOF
        env        = true
        destination = "${NOMAD_SECRETS_DIR}/secret.env"
      }

      template {
        data            = <<EOF
auth_enabled: false

analytics:
  reporting_enabled: false

server:
  http_listen_address: 127.0.0.1
  http_listen_port: 3000 # internal port

ingester:
  wal:
    flush_on_shutdown: true
  lifecycler:
    ring:
      kvstore:
        store: memberlist

schema_config:
  configs:
    - from: "2025-06-01"
      store: tsdb
      object_store: s3
      schema: v13
      index:
        prefix: "index_"
        period: 24h

storage_config:
  tsdb_shipper:
    active_index_directory: ${NOMAD_ALLOC_DIR}/loki/tsdb-index
    cache_location: ${NOMAD_ALLOC_DIR}/loki/tsdb-cache
    cache_ttl: 24h
  aws:
    s3: https://loki:$${S3_SECRET_KEY}@s3.local.{{ key "config/domains/main" }}/loki
    s3forcepathstyle: true

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  retention_period: 720h
  max_query_lookback: 720h

common:
  path_prefix: ${NOMAD_ALLOC_DIR}/loki/
  replication_factor: 1
EOF
        destination = "${NOMAD_ALLOC_DIR}/loki.yaml"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:1.28.3-alpine"
        ports = ["http"]
        volumes = [
          "local/nginx.conf:/etc/nginx/nginx.conf",
        ]
      }

      template {
        data            = <<EOF
events {}

http {
  server {
    listen {{ env "NOMAD_ALLOC_IP_http" }}:{{ env "NOMAD_PORT_http" }};

    access_log off;

    location / {
      auth_basic "Loki";
      auth_basic_user_file {{ env "NOMAD_SECRETS_DIR" }}/basic-auth-hashes;

      proxy_pass http://127.0.0.1:3000;
      proxy_http_version 1.1;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_connect_timeout 1800s;
      proxy_send_timeout 1800s;
      proxy_read_timeout 1800s;
    }
  }
}
EOF
        destination = "local/nginx.conf"
      }

      template {
        data            = <<EOF
{{ with nomadVar "nomad/jobs/loki" }}{{ .basic_auth_hashes }}{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/basic-auth-hashes"
      }

      resources {
        cpu    = 100
        memory = 64
      }

      service {
        name    = "loki"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"
      }
    }
  }
}
