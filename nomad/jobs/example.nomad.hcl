job "httpd" {
  group "httpd" {
    constraint {
      attribute = "${attr.plugins.cni.version.nebula-nomad-cni}"
      operator  = "="
      value     = "v0.1.0-ed2fe81"
    }

    network {
      port "http" {
        static = 8080
      }

      mode = "cni/nebula"
    }

    task "httpd" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo:latest"
        ports = ["http"]
        args = [
          "-listen=${NOMAD_ALLOC_IP_http}:8080",
        ]
      }

      env {
        ECHO_INCLUDE_ENV_VARS = 1
      }

      meta {
        nebula_roles = jsonencode(["test"])

        nebula_config = yamlencode({
          firewall = {
            outbound = [
              {
                port  = "any"
                proto = "any"
                host  = "any"
                cidr  = "0.0.0.0/0"
              }
            ]
            inbound = [
              {
                port  = "8080"
                proto = "tcp"
                group = "reverse-proxy"
              }
            ]
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
        name    = "httpd"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.httpd.rule=Host(`echo.local.${DOMAIN}`)",
        ]
      }
    }
  }
}
