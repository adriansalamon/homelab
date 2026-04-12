job "seaweedfs-filer" {
  type = "service"

  group "filer" {
    count = 2

    constraint {
      distinct_hosts = true
    }

    network {
      port "http" {
        static = 20090
      }
      port "grpc" {
        static = 30090
      }
      port "s3" {
        static = 30091
      }

      mode = "cni/nebula"
    }

    service {
      name = "seaweedfs-filer"
      port = "grpc"
      tags = ["grpc"]

      address_mode = "alloc"
    }

    task "filer" {
      driver = "docker"

      vault {}

      meta {
        nebula_roles = jsonencode(["postgres-client", "weed-filer"])

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
              # s3
              {
                port  = 30091
                proto = "tcp"
                group = "reverse-proxy"
              },
              {
                port  = 30091
                proto = "tcp"
                group = "nomad-client"
              },
              # http
              {
                port  = 20090
                proto = "tcp"
                group = "nomad-client"
              },
              {
                port  = 20090
                proto = "tcp"
                group = "weed-mount"
              },
              # RPC
              {
                port  = 30090
                proto = "tcp"
                group = "weed-filer"
              },
              {
                port  = 30090
                proto = "tcp"
                group = "weed-mount"
              }
            ]
          }
        })
      }

      service {
        name    = "seaweedfs-filer"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"
        tags = [
          "http",
          "filer"
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }

      service {
        name    = "seaweedfs-s3"
        port    = "s3"
        address = "${NOMAD_ALLOC_IP_s3}"
        tags = [
          "http",
          "s3",
          "traefik.enable=true",
          "traefik.http.routers.seaweedfs-s3.rule=Host(`s3.local.${DOMAIN}`)",
          "traefik.http.routers.seaweedfs-s3.entrypoints=websecure"
        ]

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        image = "chrislusf/seaweedfs:4.19"
        ports = ["http", "grpc"]

        args = [
          "filer",
          "-ip=${NOMAD_ALLOC_IP_http}",
          "-ip.bind=${NOMAD_ALLOC_IP_http}",
          "-port=${NOMAD_PORT_http}",
          "-port.grpc=${NOMAD_PORT_grpc}",
          "-master=${MASTERS}",
          "-defaultReplicaPlacement=100",
          "-s3",
          "-s3.port=${NOMAD_PORT_s3}",
          "-s3.config=/etc/seaweedfs/s3-config.json",
          "-rack=${node.unique.name}"
        ]

        volumes = [
          "local/filer.toml:/etc/seaweedfs/filer.toml",
          "local/s3-config.json:/etc/seaweedfs/s3-config.json"
        ]
      }

      template {
        data        = <<EOF
        MASTERS="{{ range service "http.seaweedfs-master" }}{{ .Address }}:{{ .Port }},{{ end }}"
        EOF
        destination = "local/masters.env"
        env         = true
      }


      template {
        data        = <<EOF
          DOMAIN="{{ key "config/domains/main" }}"
          EOF
        destination = "local/domain.env"
        env         = true
        change_mode = "noop"
      }


      template {
        data        = <<EOF
[filer.options]
# Disable local storage, use Postgres only
recursive_delete = false

[postgres2]
enabled = true
createTable = """
CREATE TABLE IF NOT EXISTS "%s" (
  dirhash   BIGINT,
  name      VARCHAR(65535),
  directory VARCHAR(65535),
  meta      bytea,
  PRIMARY KEY (dirhash, name)
);
"""
hostname = "primary.homelab-cluster.service.consul"
port = 5432
username = "seaweedfs"
database = "seaweedfs"
{{ with secret "secret/data/default/seaweedfs-filer" }}
password = "{{ .Data.data.postgres_password }}"
{{ end }}
schema = ""
sslmode = "disable"
connection_max_idle = 100
connection_max_open = 100
connection_max_lifetime_seconds = 0
EOF
        destination = "local/filer.toml"
      }


      template {
        data        = <<EOF
        {{ with secret "secret/data/default/seaweedfs-filer" }}
        {
          "identities": [
            {
              "name": "admin",
              "credentials": [{ "accessKey": "admin", "secretKey": "{{ .Data.data.admin_secret_key }}" }],
              "actions": ["Admin", "Read", "Write", "List", "Tagging"]
            },
            {
              "name": "memos",
              "credentials": [{ "accessKey": "memos", "secretKey": "{{ .Data.data.memos_secret_key }}" }],
              "actions": ["Read:memos", "Write:memos", "List:memos", "Tagging:memos"]
            },
            {
              "name": "stalwart-mail",
              "credentials": [{ "accessKey": "stalwart-mail", "secretKey": "{{ .Data.data.stalwart_secret_key }}" }],
              "actions": ["Read:stalwart-mail", "Write:stalwart-mail", "List:stalwart-mail", "Tagging:stalwart-mail"]
            },
            {
              "name": "loki",
              "credentials": [{ "accessKey": "loki", "secretKey": "{{ .Data.data.loki_secret_key }}" }],
              "actions": ["Read:loki", "Write:loki", "List:loki", "Tagging:loki"]
            },
            {
              "name": "affine",
              "credentials": [{ "accessKey": "affine", "secretKey": "{{ .Data.data.affine_secret_key }}" }],
              "actions": ["Read:affine-blobs", "Write:affine-blobs", "List:affine-blobs", "Tagging:affine-blobs"]
            }
          ]
        }
        {{ end }}
      EOF
        destination = "local/s3-config.json"
      }

      resources {
        cpu    = 500
        memory = 512
      }
    }
  }
}
