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
              # temp
              {
                port  = "any"
                proto = "tcp"
                host  = "any"
              },
              # CLIENT STUFF
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
              {
                port  = 20090
                proto = "tcp"
                group = "reverse-proxy"
              },
              {
                port  = 20090
                proto = "tcp"
                group = "nomad-client"
              },
              {
                port  = 20090
                proto = "tcp"
                group = "weed-filer-client"
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
                group = "weed-filer-client"
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
          "filer",
          "traefik.enable=true",
          "traefik.http.routers.seaweedfs-filer.rule=Host(`filer.local.${DOMAIN}`)",
          "traefik.http.routers.seaweedfs-filer.entrypoints=websecure"
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
        image = "chrislusf/seaweedfs:4.17"
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
{{ with nomadVar "nomad/jobs/seaweedfs-filer" }}
password = "{{ .postgres_password }}"
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
        {{ with nomadVar "nomad/jobs/seaweedfs-filer" }}
        {
          "identities": [
            {
              "name": "admin",
              "credentials": [{ "accessKey": "admin", "secretKey": "{{ .admin_secret_key }}" }],
              "actions": ["Admin", "Read", "Write", "List", "Tagging"]
            },
            {
              "name": "linkwarden",
              "credentials": [{ "accessKey": "linkwarden", "secretKey": "{{ .linkwarden_secret_key }}" }],
              "actions": ["Read:linkwarden", "Write:linkwarden", "List:linkwarden", "Tagging:linkwarden"]
            },
            {
              "name": "memos",
              "credentials": [{ "accessKey": "memos", "secretKey": "{{ .memos_secret_key }}" }],
              "actions": ["Read:memos", "Write:memos", "List:memos", "Tagging:memos"]
            },
            {
              "name": "stalwart-mail",
              "credentials": [{ "accessKey": "stalwart-mail", "secretKey": "{{ .stalwart_secret_key }}" }],
              "actions": ["Read:stalwart-mail", "Write:stalwart-mail", "List:stalwart-mail", "Tagging:stalwart-mail"]
            },
            {
              "name": "loki",
              "credentials": [{ "accessKey": "loki", "secretKey": "{{ .loki_secret_key }}" }],
              "actions": ["Read:loki", "Write:loki", "List:loki", "Tagging:loki"]
            },
            {
              "name": "affine",
              "credentials": [{ "accessKey": "affine", "secretKey": "{{ .affine_secret_key }}" }],
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
