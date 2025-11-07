job "linkwarden" {
  type        = "service"

  group "linkwarden" {
    count = 1

    network {
      mode = "cni/flannel"
      port "http" {
        to = 3000
      }
    }

    task "linkwarden" {
      driver = "docker"

      service {
        name     = "linkwarden"
        port     = "http"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.linkwarden.rule=Host(`linkwarden.${DOMAIN}`)",
          "traefik.http.routers.linkwarden.entrypoints=websecure"
        ]

        check {
          type     = "tcp"
          port     = "http"
          interval = "30s"
          timeout  = "10s"
        }
      }

      config {
        image = "ghcr.io/linkwarden/linkwarden:v2.13.1"
        ports = ["http"]
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      template {
        data        = <<EOF
         DOMAIN="{{ key "config/domains/main" }}"
         NEXTAUTH_URL="https://linkwarden.${DOMAIN}/api/v1/auth"
         NEXT_PUBLIC_CREDENTIALS_ENABLED="false"

         SPACES_ENDPOINT="https://s3.local.${DOMAIN}"
         SPACES_BUCKET_NAME="linkwarden"
         SPACES_REGION="us-east-1"
         SPACES_FORCE_PATH_STYLE="true"

         NEXT_PUBLIC_AUTHELIA_ENABLED="true"
         AUTHELIA_WELLKNOWN_URL="https://auth.${DOMAIN}/.well-known/openid-configuration"
         AUTHELIA_CLIENT_ID="linkwarden"
        EOF
        destination = "local/config.env"
        env         = true
      }

      template {
        data        = <<EOF
          {{ with nomadVar "nomad/jobs/linkwarden" }}
          NEXTAUTH_SECRET="{{ .nextauth_secret }}"
          AUTHELIA_CLIENT_SECRET="{{ .oidc_client_secret }}"
          DATABASE_URL="postgresql://linkwarden:{{ .postgres_password }}@master.homelab-cluster.service.consul:5432/linkwarden"
          SPACES_KEY=linkwarden
          SPACES_SECRET={{ .s3_secret_key }}
          {{ end }}
        EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
      }
    }
  }
}
