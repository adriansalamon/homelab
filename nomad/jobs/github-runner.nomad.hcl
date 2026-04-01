job "github-runner" {
  type = "batch"

  # Parameterized job - triggered by webhook server
  parameterized {
    payload       = "forbidden"
    meta_required = ["github_url", "runner_token", "runner_labels"]
  }

  # made for building nix derivations
  group "runner" {

    volume "nix-store" {
      type      = "host"
      source    = "nix-store"
      read_only = true
    }

    volume "nix-daemon-socket" {
      type      = "host"
      source    = "nix-daemon-socket"
      read_only = false
    }

    volume "nix-bin" {
      type      = "host"
      source    = "nix-bin"
      read_only = true
    }

    task "runner" {
      driver = "docker"

      config {
        image = "ghcr.io/adriansalamon/github-runner:self-hosted-runner-e2089d1"
      }

      volume_mount {
        volume      = "nix-store"
        destination = "/nix/store"
        read_only   = true
      }

      volume_mount {
        volume      = "nix-daemon-socket"
        destination = "/nix/var/nix/daemon-socket"
        read_only   = false
      }

      volume_mount {
        volume      = "nix-bin"
        destination = "/nix-bin"
        read_only   = true
      }

      env {
        GITHUB_URL    = "${NOMAD_META_github_url}"
        RUNNER_TOKEN  = "${NOMAD_META_runner_token}"
        RUNNER_LABELS = "${NOMAD_META_runner_labels}"

        NIX_REMOTE = "daemon"
        PATH       = "/nix-bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        NIX_CONFIG = "experimental-features = nix-command flakes"
      }

      resources {
        cpu        = 2000
        memory     = 3072 # Needs a lot of memory for nix builds
        memory_max = 6144
      }

      # No automatic restarts - ephemeral runners are one-time use
      restart {
        attempts = 0
        mode     = "fail"
      }

      # Give the runner time to gracefully shut down
      kill_timeout = "30s"
    }
  }
}
