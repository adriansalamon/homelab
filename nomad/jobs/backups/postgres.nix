{
  lib,
  helpers,
  ...
}:
let
  resticOpts = helpers.resticOpts "postgres";

  script = ''
    set -e

    # Install restic and openssh for backup
    echo "Installing restic and openssh..."
    apk add --no-cache restic openssh-client curl

    # Set up SSH directory and known_hosts
    mkdir -p /root/.ssh
    cp /local/known_hosts /root/.ssh/known_hosts
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/known_hosts

    # Wait for PostgreSQL to be available
    echo "Waiting for PostgreSQL to be available..."
    until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER"; do
      echo "PostgreSQL is unavailable - sleeping"
      sleep 2
    done
    echo "PostgreSQL is available"

    # Create backup directory
    mkdir -p /backup
    DUMP_FILE="/backup/patroni-$(date +%Y%m%d-%H%M%S).sql.gz"

    # Dump all databases using credentials from Vault
    echo "Dumping all databases to $DUMP_FILE..."
    pg_dumpall --clean --if-exists | gzip > "$DUMP_FILE"

    echo "Database dump completed. Size: $(du -h "$DUMP_FILE" | cut -f1)"

    # Initialize the repository if it doesn't exist
    echo "Initializing restic repository if needed..."
    restic ${resticOpts} cat config > /dev/null || restic ${resticOpts} init

    # Backup the dump to Hetzner
    echo "Uploading backup to Hetzner Storage Box..."
    restic ${resticOpts} backup "$DUMP_FILE" --tag postgres --tag patroni

    # Unlock the repository
    restic ${resticOpts} unlock

    # Prune old snapshots
    echo "Pruning old backups..."
    restic ${resticOpts} forget --prune --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --tag postgres

    echo "Backup completed successfully!"
  '';
in
{
  job.backup-postgres = {
    type = "batch";

    # Run daily at 03:30 UTC (before other backups)
    periodic = {
      crons = [ "30 3 * * *" ];
      prohibitOverlap = true;
      timeZone = "UTC";
    };

    group.backup = {
      count = 1;

      networks = [
        {
          mode = "cni/nebula";
        }
      ];

      task.backup-postgres = {
        driver = "docker";

        # Enable Vault integration with custom role for database access
        vault = {
          role = "postgres-backup";
        };

        meta = helpers.mkNebula {
          groups = [ "postgres-client" ];
        };

        env = {
          RESTIC_REPOSITORY = "rclone:";
          PGHOST = "primary.homelab-cluster.service.consul";
          PGPORT = "5432";
        };

        config = {
          # Use PostgreSQL image that includes pg_dumpall
          image = "postgres:16-alpine";
          entrypoint = [ "/bin/sh" ];
          args = [
            "-c"
            script
          ];
        };

        templates = [
          # Get dynamic PostgreSQL credentials from Vault database engine
          {
            data = ''
              {{ with secret "database/creds/backup" }}
              PGUSER={{ .Data.username }}
              PGPASSWORD={{ .Data.password }}
              {{ end }}
            '';
            destination = "\${NOMAD_SECRETS_DIR}/postgres.env";
            env = true;
            perms = "0600";
          }
          # Get restic password from KV secrets
          {
            data = ''
              {{ with secret "secret/data/default/backup-postgres" }}
              RESTIC_PASSWORD={{ .Data.data.restic_password }}
              {{ end }}
            '';
            destination = "\${NOMAD_SECRETS_DIR}/restic.env";
            env = true;
            perms = "0600";
          }
          # Get SSH private key for Hetzner access
          {
            data = ''
              {{ with secret "secret/data/default/backup-postgres" }}{{ .Data.data.ssh_private_key }}{{ end }}
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
          cpu = 500;
          memory = 1024;
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
