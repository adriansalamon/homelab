job "docs" {

  group "example" {
    count = 2
    network {
      mode = "bridge"
      port "http" {
        to = 5678
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = "hashicorp/http-echo"
        ports = ["http"]
        args = [
          "-listen",
          ":5678",
          "-text",
          "hello world",
        ]
      }

      service {
        port = "http"

        check {
          type = "http"
          path = "/"
          interval = "10s"
          timeout = "2s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.docs.rule=Host(`docs.local.salamon.xyz`)"
        ]
      }
    }
  }
}
