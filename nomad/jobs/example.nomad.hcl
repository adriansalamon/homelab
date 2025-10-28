job "httpd" {
  group "httpd" {
    network {
      port "http" {
        to = 8080
      }

      mode = "cni/flannel"
    }


    template {
      data        = <<EOF
      DOMAIN="{{ key "config/domains/main" }}"
      EOF
      destination = "local/domain.env"
      env         = true
    }

    service {
      name = "httpd"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.httpd.rule=Host(`echo.local.${DOMAIN}`)",
      ]
    }

    task "httpd" {
      driver = "docker"

      env {
        ECHO_INCLUDE_ENV_VARS = 1
      }

      config {
        image = "mendhak/http-https-echo:latest"
        ports = ["http"]
      }
    }
  }
}
