locals {
  port_http = 26855
}

job "linkding" {
  type = "service"

  group "linkding" {
    count = 1

    network {
      mode = "cni/nebula"
      port "http" {
        static = local.port_http
      }
    }

    volume "linkding-data" {
      type            = "csi"
      source          = "linkding-data"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-single-writer"
    }

    task "linkding" {
      driver = "docker"

      volume_mount {
        volume      = "linkding-data"
        destination = "/etc/linkding/data"
        read_only   = false
      }

      config {
        image = "ghcr.io/sissbruecker/linkding:1.45.0-plus"
        ports = ["http"]
      }

      meta {
        nebula_roles = jsonencode(["postgres-client"])

        nebula_config = yamlencode({
          firewall = {
            outbound = [
              {
                port  = "any"
                proto = "any"
                host  = "any"
              }
            ]
            inbound = [for group in ["reverse-proxy", "nomad-client"] : {
              port  = local.port_http
              proto = "tcp"
              group = group
            }]
          }
        })
      }

      template {
        data        = <<EOF
{{ $domain := key "config/domains/main" }}
DOMAIN="{{ $domain }}"
LD_DB_ENGINE=postgres
LD_DB_HOST=master.homelab-cluster.service.consul
LD_DB_PORT=5432
LD_DB_DATABASE=linkding
LD_DB_USER=linkding
LD_SERVER_HOST={{ env "NOMAD_ALLOC_IP_http" }}
LD_SERVER_PORT={{ env "NOMAD_PORT_http" }}
LD_ENABLE_AUTH_PROXY=True
LD_AUTH_PROXY_USERNAME_HEADER=HTTP_REMOTE_USER
LD_AUTH_PROXY_LOGOUT_URL=https://auth.{{ $domain }}/logout
LD_DISABLE_LOGIN_FORM=True
LD_USE_X_FORWARDED_HOST=True
EOF
        destination = "local/config.env"
        env         = true
      }

      template {
        data        = <<EOF
{{ with nomadVar "nomad/jobs/linkding" }}
LD_DB_PASSWORD={{ .postgres_password }}
{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
        perms       = "0600"
      }

      service {
        name    = "linkding"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.http.routers.linkding.rule=Host(`links.${DOMAIN}`)",
          "traefik.http.routers.linkding.entrypoints=websecure",
          "traefik.http.routers.linkding.middlewares=authelia",

          # Health check, don't need auth middleware
          "traefik.http.routers.linkding-health.rule=Host(`links.${DOMAIN}`) && Path(`/health`)",
          "traefik.http.routers.linkding-health.entrypoints=websecure",
        ]

        check {
          type     = "http"
          path     = "/health"
          port     = "http"
          interval = "30s"
          timeout  = "10s"
        }
      }

      resources {
        cpu    = 250
        memory = 512
      }
    }
  }
}
