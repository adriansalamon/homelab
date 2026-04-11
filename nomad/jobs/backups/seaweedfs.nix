{
  lib,
  globals,
  helpers,
  ...
}:
let
  resticOpts = helpers.resticOpts "seaweedfs";

  # Buckets to backup (excluding loki - logs not critical)
  bucketsToBackup = [
    "affine-blobs"
    "linkding-data"
    "memos"
    "stalwart-mail"
  ];

  script = ''
    set -e

    # Setup functions
    setup_environment() {
      echo "Installing dependencies..."
      apk add --no-cache rclone restic openssh-client fuse3 curl ca-certificates
      mkdir -p /root/.ssh /mnt/s3
      cp /local/known_hosts /root/.ssh/known_hosts
      chmod 700 /root/.ssh && chmod 600 /root/.ssh/known_hosts
    }

    mount_bucket() {
      local bucket=$1
      local mount_point="/mnt/s3/$bucket"
      echo "Mounting $bucket..."
      mkdir -p "$mount_point"

      rclone mount seaweedfs:$bucket "$mount_point" \
        --config "$NOMAD_SECRETS_DIR/rclone.conf" \
        --daemon --vfs-cache-mode writes --allow-other \
        --log-level DEBUG --log-file /tmp/rclone-$bucket.log &
      local pid=$!

      # Wait for mount
      for i in $(seq 1 30); do
        mountpoint -q "$mount_point" && { echo "✓ Mounted"; return 0; }
        kill -0 $pid 2>/dev/null || {
          echo "ERROR: Mount failed"
          cat /tmp/rclone-$bucket.log 2>/dev/null
          return 1
        }
        sleep 1
      done
      echo "ERROR: Mount timeout" && kill $pid 2>/dev/null && return 1
    }

    backup_bucket() {
      local bucket=$1
      echo "========================================="
      echo "Backing up: $bucket"
      echo "========================================="

      mount_bucket "$bucket" || exit 1
      restic ${resticOpts} backup /mnt/s3/$bucket \
        --tag seaweedfs --tag $bucket --host seaweedfs
      fusermount -u /mnt/s3/$bucket 2>/dev/null || true
      sleep 2
      echo "✓ Complete: $bucket"
    }

    # Main execution
    setup_environment
    echo "Initializing restic repository..."
    restic ${resticOpts} cat config >/dev/null 2>&1 || restic ${resticOpts} init

    ${lib.concatMapStringsSep "\n" (bucket: ''backup_bucket "${bucket}"'') bucketsToBackup}

    echo "Cleaning up..."
    restic ${resticOpts} unlock
    restic ${resticOpts} forget --prune \
      --keep-daily 14 --keep-weekly 8 --keep-monthly 12 --tag seaweedfs

    echo "========================================="
    echo "✓ All backups completed!"
    echo "========================================="
  '';
in
{
  job.backup-seaweedfs = {
    type = "batch";

    # Run daily at 04:30 UTC (after PostgreSQL backup)
    periodic = {
      crons = [ "30 4 * * *" ];
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

      task.backup-seaweedfs = {
        driver = "docker";

        vault = { };

        meta = helpers.mkNebula {
          groups = [ "weed-filer-client" ];
        };

        env = {
          RESTIC_REPOSITORY = "rclone:";
        };

        config = {
          image = "alpine:3.23";
          entrypoint = [ "/bin/sh" ];
          args = [
            "-c"
            script
          ];

          # Need privileged mode for FUSE mounts
          privileged = true;

          # Mount /dev/fuse
          devices = [
            {
              host_path = "/dev/fuse";
              container_path = "/dev/fuse";
            }
          ];
        };

        templates = [
          # Environment variables (restic password)
          {
            data = ''
              {{ with secret "secret/data/default/backup-seaweedfs" }}
              RESTIC_PASSWORD={{ .Data.data.restic_password }}
              {{ end }}
            '';
            destination = "\${NOMAD_SECRETS_DIR}/secrets.env";
            env = true;
            perms = "0600";
          }
          # SSH private key for Hetzner
          {
            data = ''
              {{ with secret "secret/data/default/backup-seaweedfs" }}{{ .Data.data.ssh_private_key }}{{ end }}
            '';
            destination = "\${NOMAD_SECRETS_DIR}/restic-ssh-privkey";
            perms = "0600";
          }
          # rclone configuration with S3 credentials
          {
            data = ''
              {{ with secret "secret/data/default/backup-seaweedfs" }}
              [seaweedfs]
              type = s3
              provider = Other
              env_auth = false
              access_key_id = admin
              secret_access_key = {{ .Data.data.s3_secret_key }}
              endpoint = https://s3.local.${globals.domains.main}
              acl = private
              no_check_bucket = true
              {{ end }}
            '';
            destination = "\${NOMAD_SECRETS_DIR}/rclone.conf";
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
          cpu = 800;
          memory = 1536;
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
