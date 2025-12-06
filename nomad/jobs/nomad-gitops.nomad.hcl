job "nomad-gitops" {
  type        = "service"

  group "operator" {
    count = 1

    network {
      mode = "cni/flannel"
    }

    task "nomad-gitops" {
      driver = "docker"

      config {
        image = "ghcr.io/adriansalamon/nomad-gitops:main-b3887fa"
      }

      resources {
        cpu    = 100
        memory = 256
      }

      restart {
        interval = "1m"
        attempts = 3
        delay    = "15s"
        mode     = "delay"
      }

      template {
        data = <<EOT
          # Git configuration
          GIT_URL = "https://github.com/adriansalamon/homelab"
          GIT_BRANCH = "main"
          GIT_SYNC_INTERVAL = "5m"
          GIT_LOCAL_PATH = "{{ env "NOMAD_ALLOC_DIR" }}/repo"
          NOMAD_JOB_PATHS = "nomad/jobs/*.nomad.hcl,nomad/**/*.nomad.hcl"

          # Nomad configuration
          NOMAD_ADDR = "https://nomad.local.{{ key "config/domains/main" }}"
          CONSUL_HTTP_ADDR = "http://consul.service.consul:8500"

          LOG_LEVEL = "info"
        EOT
        env = true
        destination = "local/config.env"
      }

      template {
        data = <<EOT
          {{ with nomadVar "nomad/jobs/nomad-gitops" }}
          CONSUL_HTTP_TOKEN={{ .consul_token }}
          NOMAD_TOKEN={{ .nomad_token }}
          {{ end }}
        EOT
        env = true
        destination = "${NOMAD_SECRETS_DIR}/secrets.env"
      }
    }
  }
}
