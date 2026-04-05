job "affine" {
  type = "service"

  group "affine" {
    count = 1

    network {
      mode = "cni/nebula"
      port "http" {
        static = 17288
      }
    }

    task "affine" {
      driver = "docker"

      config {
        image = "ghcr.io/toeverything/affine:0.26.6"
        ports = ["http"]
        volumes = [
          "local/config:/root/.affine/config"
        ]
      }

      meta {
        nebula_roles = jsonencode(["postgres-client", "redis-client"])

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
              port  = "17288"
              proto = "tcp"
              group = group
            }]
          }
        })
      }

      template {
        data        = <<EOF
DOMAIN={{ key "config/domains/main" }}
REDIS_SERVER_HOST=master.redis.service.consul
REDIS_SERVER_PORT=6379
EOF
        destination = "local/env.env"
        env         = true
      }

      template {
        data        = <<EOF
{{ with nomadVar "nomad/jobs/affine" }}
DATABASE_URL=postgresql://affine:{{ .postgres_password }}@master.homelab-cluster.service.consul:5432/affine
REDIS_SERVER_PASSWORD={{ .redis_password }}
{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
        perms       = "0600"
      }


      template {
        destination = "/root/.affine/config/private.key"
        data        = <<EOT
{{ with nomadVar "nomad/jobs/affine" }}{{ .private_key }}{{ end }}
EOT
      }


      # AFFiNE configuration file
      template {
        data        = <<EOF
{{ $domain := key "config/domains/main" }}
{{ with nomadVar "nomad/jobs/affine" }}
{
  "server": {
    "host": "affine.{{ $domain }}",
    "https": true,
    "externalUrl": "https://affine.{{ $domain }}",
    "port": {{ env "NOMAD_PORT_http" }},
    "listenAddr": "{{ env "NOMAD_ALLOC_IP_http" }}"
  },
  "auth": {
    "allowSignup": true,
    "allowSignupForOauth": true
  },
  "oauth": {
    "providers.oidc": {
      "clientId": "affine",
      "clientSecret": "{{ .oidc_client_secret }}",
      "issuer": "https://auth.{{ $domain }}",
      "args": {
        "scope": "openid profile email",
        "claim_id": "preferred_username",
        "claim_name": "name",
        "claim_email": "email"
      }
    }
  },
  "storages": {
    "blob": {
      "storage": {
        "provider": "aws-s3",
        "bucket": "affine-blobs",
        "config": {
          "endpoint": "https://s3.local.{{ $domain }}",
          "region": "us-east-1",
          "forcePathStyle": true,
          "credentials": {
            "accessKeyId": "affine",
            "secretAccessKey": "{{ .s3_secret_key }}"
          }
        }
      }
    }
  }
}
{{ end }}
EOF
        destination = "local/config/config.json"
        perms       = "0644"
      }

      service {
        name    = "affine"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          #"traefik.external=true",
          "traefik.http.routers.affine.rule=Host(`affine.${DOMAIN}`)",
          "traefik.http.routers.affine.entrypoints=websecure"
        ]
      }

      resources {
        cpu    = 1000
        memory = 2048
      }
    }


    task "migrate" {
      lifecycle {
        hook    = "prestart"
        sidecar = false
      }

      driver = "docker"

      config {
        image   = "ghcr.io/toeverything/affine:0.26.6"
        ports   = ["http"]
        command = "node"
        args    = ["./scripts/self-host-predeploy.js"]
      }

      template {
        destination = "/root/.affine/config/private.key"
        data        = <<EOT
{{ with nomadVar "nomad/jobs/affine" }}{{ .private_key }}{{ end }}
EOT
      }

      template {
        data        = <<EOF
REDIS_SERVER_HOST=master.redis.service.consul
REDIS_SERVER_PORT=6379
AFFINE_INDEXER_ENABLED=false
{{ with nomadVar "nomad/jobs/affine" }}
DATABASE_URL=postgresql://affine:{{ .postgres_password }}@master.homelab-cluster.service.consul:5432/affine
REDIS_SERVER_PASSWORD={{ .redis_password }}
{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
        env         = true
        perms       = "0600"
      }
    }
  }
}
