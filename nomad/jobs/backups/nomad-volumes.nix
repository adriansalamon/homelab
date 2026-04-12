{
  lib,
  helpers,
  ...
}:
let
  resticOpts = helpers.resticOpts "nomad-volumes";
in
{
  job.backup-nomad-volumes = {
    type = "batch";

    # Run daily at 04:00 UTC
    periodic = {
      crons = [ "0 4 * * *" ];
      prohibitOverlap = true;
      timeZone = "UTC";
    };

    group.backup = {
      count = 1;

      networks = lib.singleton { mode = "cni/nebula"; };

      # Mount the opengist volume
      volume."opengist-data" = {
        type = "host";
        source = "opengist-data";
        readOnly = true;
      };

      task.backup-volumes = {
        driver = "docker";

        vault = { };

        # Mount the volume
        volumeMounts = [
          {
            volume = "opengist-data";
            destination = "/data/opengist";
            readOnly = true;
          }
        ];

        env = {
          RESTIC_REPOSITORY = "rclone:";
        };

        config = {
          image = "restic/restic:0.18.1";
          entrypoint = [ "/bin/sh" ];
          args = [
            "-c"
            ''
              set -e
              # Set up SSH directory and known_hosts
              mkdir -p /root/.ssh
              cp /local/known_hosts /root/.ssh/known_hosts
              chmod 700 /root/.ssh
              chmod 600 /root/.ssh/known_hosts

              # Initialize the repository if it doesn't exist
              restic ${resticOpts} cat config > /dev/null || restic ${resticOpts} init

              # Backup all volumes
              restic ${resticOpts} backup /data/opengist

              # Unlock the repository
              restic ${resticOpts} unlock

              # Prune old snapshots
              restic ${resticOpts} forget --prune --keep-daily 14 --keep-weekly 8 --keep-monthly 12
            ''
          ];
        };

        templates = [
          {
            data = ''
              {{ with secret "secret/data/default/backup-nomad-volumes" }}
              RESTIC_PASSWORD={{ .Data.data.restic_password }}
              {{ end }}
            '';
            destination = "\${NOMAD_SECRETS_DIR}/restic.env";
            env = true;
            perms = "0600";
          }
          {
            data = ''
              {{ with secret "secret/data/default/backup-nomad-volumes" }}{{ .Data.data.ssh_private_key }}{{ end }}
            '';
            destination = "\${NOMAD_SECRETS_DIR}/restic-ssh-privkey";
            perms = "0600";
          }
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
