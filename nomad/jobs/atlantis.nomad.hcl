job "atlantis" {
  type = "service"

  group "atlantis" {
    count = 1

    network {
      mode = "cni/nebula"
      port "http" {
        static = 4141
      }
    }

    ephemeral_disk {
      size   = 1000
      sticky = true
    }

    task "atlantis" {
      driver = "docker"

      config {
        image = "ghcr.io/adriansalamon/atlantis:main-994244f"
        ports = ["http"]

        # Use server-side repo config
        args = [
          "server",
          "--repo-config=${NOMAD_TASK_DIR}/repos.yaml"
        ]
      }

      # Nebula firewall configuration
      meta {
        nebula_roles = jsonencode([])

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
              {
                port  = "4141"
                proto = "tcp"
                group = "reverse-proxy"
              },
              {
                port  = "4141"
                proto = "tcp"
                group = "nomad-client"
              }
            ]
          }
        })
      }

      # Environment variables
      env {
        # Atlantis server configuration
        ATLANTIS_REPO_ALLOWLIST           = "github.com/adriansalamon/homelab"
        ATLANTIS_PORT                     = "${NOMAD_PORT_http}"
        ATLANTIS_WRITE_GIT_CREDS          = true
        ATLANTIS_TFE_LOCAL_EXECUTION_MODE = true

        # Nomad/Consul access
        NOMAD_ADDR       = "https://nomad.local.${DOMAIN}"
        CONSUL_HTTP_ADDR = "https://consul.local.${DOMAIN}"
      }

      # Secrets from Nomad variables
      template {
        data        = <<EOF
ATLANTIS_ATLANTIS_URL = "https://atlantis.{{ key "config/domains/main" }}"
{{ with nomadVar "nomad/jobs/atlantis" }}
ATLANTIS_GH_APP_ID={{ .github_app_id }}
ATLANTIS_GH_APP_KEY_FILE={{ env "NOMAD_SECRETS_DIR" }}/app-key.pem
ATLANTIS_GH_WEBHOOK_SECRET={{ .github_webhook_secret }}
AGECRYPT_KEY={{ .agecrypt_key }}
NOMAD_TOKEN={{ .nomad_token }}
CONSUL_HTTP_TOKEN={{ .consul_token }}
{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/atlantis.env"
        env         = true
        perms       = "0600"
      }

      template {
        data        = <<EOF
{{ with nomadVar "nomad/jobs/atlantis" }}{{ .github_app_key }}{{ end }}
EOF
        destination = "${NOMAD_SECRETS_DIR}/app-key.pem"
      }

      # Server-side repo configuration
      # Note: Workflows are defined in atlantis.yaml in the repo
      template {
        data        = <<EOF
repos:
- id: github.com/adriansalamon/homelab
  allow_custom_workflows: true
  allowed_overrides: [workflow, apply_requirements]

  pre_workflow_hooks:
    - run: |
        echo "🔐 Decrypting age-encrypted files..."
        echo "$AGECRYPT_KEY" | base64 -d > /tmp/key.txt
        nix run nixpkgs#git-agecrypt init
        nix run nixpkgs#git-agecrypt config -- add -i /tmp/key.txt
        rm .git/index
        git checkout HEAD -- "$(git rev-parse --show-toplevel)"
        rm /tmp/key.txt

        # Verify decryption worked by checking if file is still encrypted
        if head -n1 global.nix | grep -q "age-encryption.org"; then
          echo "❌ Decryption failed"
          exit 1
        else
          echo "✅ Secrets decrypted successfully"
        fi
EOF
        destination = "${NOMAD_TASK_DIR}/repos.yaml"
        perms       = "0644"
      }

      # Domain template
      template {
        data        = <<EOF
DOMAIN="{{ key "config/domains/main" }}"
EOF
        destination = "local/domain.env"
        env         = true
      }

      resources {
        cpu    = 1000
        memory = 3072 # Increased for Nix builds (was getting OOM killed at 2GB)
      }

      service {
        name    = "atlantis-pub"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          "traefik.external=true",
          "traefik.http.routers.atlantis-pub.rule=Host(`atlantis.${DOMAIN}`) && Path(`/events`)",
          "traefik.http.routers.atlantis-pub.entrypoints=websecure"
        ]
      }

      service {
        name    = "atlantis"
        port    = "http"
        address = "${NOMAD_ALLOC_IP_http}"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.atlantis.rule=Host(`atlantis.${DOMAIN}`)",
        ]
      }
    }
  }
}
