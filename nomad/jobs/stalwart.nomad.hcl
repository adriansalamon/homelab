job "stalwart" {
  type = "service"

  group "stalwart" {
    count = 1

    network {
      mode = "cni/nebula"

      port "smtp" { static = 25 }
      port "submission" { static = 587 }
      port "imaps" { static = 993 }
    }

    service {
      name    = "stalwart-http"
      port    = "8080"
      address_mode = "alloc"

      tags = [
        "traefik.enable=true",
        "traefik.external=true",
        "traefik.http.routers.stalwart.rule=Host(`mail.salamon.xyz`)",
        "traefik.http.routers.stalwart.entrypoints=websecure",
      ]
    }

    task "stalwart" {
      driver = "docker"

      vault {}

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
            inbound = concat(
              flatten([
                for group, ports in {
                  "reverse-proxy" = ["25", "587", "993", "8080"]
                  "nomad-client"  = ["8080"]
                  } : [
                  for port in ports : {
                    group = group
                    proto = "tcp"
                    port  = port
                  }
                ]
              ]),
              [
                {
                  group = "metrics-collector"
                  proto = "tcp"
                  port  = "9191"
                }
              ]
            )
          }
        })
      }

      config {
        image = "stalwartlabs/stalwart:v0.16.1"
        ports = ["submission", "imaps", "http"]

        volumes = [
          "local/config.json:/etc/stalwart/config.json"
        ]
      }

      template {
        destination = "local/config.json"
        data        = <<EOF
{
  "@type": "PostgreSql",{{ range service "primary.homelab-cluster" }}
  "host": "{{ .Address }}",
  "port": {{ .Port }},{{ end }}
  "database": "stalwart",
  "authUsername": "stalwart",
  "useTls": false,
  "authSecret": {
    "@type": "Value",
    "secret": "{{ with secret "secret/data/default/stalwart" }}{{ .Data.data.postgres_password }}{{ end }}"
  }
}
EOF
      }

      resources {
        cpu    = 3000
        memory = 500
      }

      template {
        data        = <<EOF
DOMAIN="{{ key "config/domains/main" }}"
EOF
        destination = "local/domain.env"
        env         = true
      }

      template {
        data        = <<EOF
STALWART_RECOVERY_ADMIN="admin:{{ with secret "secret/data/default/stalwart" }}{{ .Data.data.admin_password }}{{ end }}"
EOF
        destination = "${NOMAD_SECRETS_DIR}/stalwart-admin.env"
        env         = true
      }


      service {
        name    = "stalwart-smtp"
        port    = "smtp"
        address = "${NOMAD_ALLOC_IP_smtp}"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.tcp.routers.smtp.rule=HostSNI(`*`)",
          "traefik.tcp.routers.smtp.entrypoints=smtp",
          "traefik.tcp.services.stalwart-smtp.loadBalancer.serversTransport=proxy@file"
        ]
      }

      service {
        name    = "stalwart-submission"
        port    = "submission"
        address = "${NOMAD_ALLOC_IP_smtp}"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.tcp.routers.submission.rule=HostSNI(`*`)",
          "traefik.tcp.routers.submission.entrypoints=submission",
          "traefik.tcp.services.stalwart-submission.loadBalancer.serversTransport=proxy@file"
        ]
      }

      service {
        name    = "stalwart-imaps"
        port    = "imaps"
        address = "${NOMAD_ALLOC_IP_smtp}"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.tcp.routers.imaps.rule=HostSNI(`*`)",
          "traefik.tcp.routers.imaps.entrypoints=imaps",
          "traefik.tcp.services.stalwart-imaps.loadBalancer.serversTransport=proxy@file"
        ]
      }
    }
  }
}
