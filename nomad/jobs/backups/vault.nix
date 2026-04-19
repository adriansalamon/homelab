{
  lib,
  helpers,
  ...
}:
let
  resticOpts = helpers.resticOpts "vault";

  script = ''
    set -e

    # Setup functions
    setup_environment() {
      echo "Installing dependencies..."
      apk add --no-cache restic openssh-client curl ca-certificates
      mkdir -p /root/.ssh /backup
      cp /local/known_hosts /root/.ssh/known_hosts
      chmod 700 /root/.ssh && chmod 600 /root/.ssh/known_hosts
    }

    create_vault_snapshot() {
      local snapshot_file="/backup/vault-snapshot-$(date +%Y%m%d-%H%M%S).snap"

      echo "Creating Vault raft snapshot..." >&2
      vault operator raft snapshot save "$snapshot_file" || {
        echo "ERROR: Failed to create snapshot" >&2
        exit 1
      }

      local size=$(du -h "$snapshot_file" | cut -f1)
      echo "✓ Snapshot created: $snapshot_file ($size)" >&2
      # Only output the filename to stdout so it can be captured
      echo "$snapshot_file"
    }

    backup_snapshot() {
      local snapshot_file=$1

      echo "Backing up snapshot to Hetzner..." >&2
      restic ${resticOpts} backup "$snapshot_file" \
        --tag vault --tag raft-snapshot --host vault

      echo "✓ Backup complete" >&2
    }

    # Main execution
    setup_environment

    echo "Initializing restic repository..."
    restic ${resticOpts} cat config >/dev/null 2>&1 || restic ${resticOpts} init

    snapshot_file=$(create_vault_snapshot)
    backup_snapshot "$snapshot_file"

    echo "Cleaning up..."
    restic ${resticOpts} unlock
    restic ${resticOpts} forget --prune \
      --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --tag vault

    echo "========================================="
    echo "✓ Vault backup completed!"
    echo "========================================="
  '';
in
{
  job.backup-vault = {
    type = "batch";

    # Run daily at 03:00 UTC (before other backups)
    periodic = {
      crons = [ "0 3 * * *" ];
      prohibitOverlap = true;
      timeZone = "UTC";
    };

    group.backup = {
      count = 1;

      networks = lib.singleton { mode = "cni/nebula"; };

      task.backup-vault = {
        driver = "docker";

        vault = {
          role = "vault-backup";
        };

        meta = helpers.mkNebula {
          groups = [ "vault-client" ];
        };

        env = {
          RESTIC_REPOSITORY = "rclone:";
          # Use Consul DNS to reach the active Vault leader directly
          VAULT_ADDR = "https://active.vault.service.consul:8200";
          VAULT_SKIP_VERIFY = "true"; # Using internal TLS cert
        };

        config = {
          # Use Vault image that includes vault CLI
          image = "hashicorp/vault:1.21";
          entrypoint = [ "/bin/sh" ];
          args = [
            "-c"
            script
          ];
        };

        templates = [
          {
            data = ''
              {{ with secret "secret/data/default/backup-vault" }}
              RESTIC_PASSWORD={{ .Data.data.restic_password }}
              {{ end }}
            '';
            destination = "\${NOMAD_SECRETS_DIR}/restic.env";
            env = true;
            perms = "0600";
          }
          {
            data = ''
              {{ with secret "secret/data/default/backup-vault" }}{{ .Data.data.ssh_private_key }}{{ end }}
            '';
            destination = "\${NOMAD_SECRETS_DIR}/restic-ssh-privkey";
            perms = "0600";
          }
          # Hetzner Storage Box SSH host key
          {
            data = ''
              [u498058.your-storagebox.de]:23 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs
            '';
            destination = "local/known_hosts";
          }
        ];

        resources = {
          cpu = 200;
          memory = 512;
        };

        restart = {
          attempts = 2;
          delay = 30 * lib.time.second;
          mode = "fail";
        };
      };
    };
  };
}
