{
  config,
  lib,
  globals,
  pkgs,
  ...
}:
let
  inherit (lib)
    any
    attrValues
    flip
    mkIf
    mkMerge
    mkOption
    optionals
    types
    ;

  anyPostgres = any (boxCfg: boxCfg.withPostgres) (attrValues config.meta.backups.storageboxes);
in
{

  options.meta.backups.storageboxes = mkOption {
    description = "Module to configure automatic backups to Hetzner Storage Boxes";
    default = { };
    type = types.attrsOf (
      types.submodule (submod: {
        options = {
          name = mkOption {
            description = "The name of the storage box to backup to. The box must be defined in the globals. Defaults to the attribute name.";
            default = submod.config._module.args.name;
            type = types.str;
          };

          subuser = mkOption {
            description = "The name of the subuser. Must be defined in the globals.";
            type = types.str;
          };

          paths = mkOption {
            description = "The paths to backup.";
            type = types.listOf types.str;
          };

          withPostgres = mkOption {
            description = "Whether to enable and configure services.postgresqlBackup to also backup all postgres databases.";
            type = types.bool;
            default = false;
          };
        };
      })
    );
  };

  config = mkIf (config.meta.backups.storageboxes != { }) {
    age.secrets.restic-encryption-password.generator.script = "alnum";
    age.secrets.restic-ssh-privkey.generator.script = "ssh-ed25519";

    environment.systemPackages = with pkgs; [
      restic
    ];
    users.users.restic = {
      group = "restic";
      isSystemUser = true;
    };
    users.groups.restic = { };

    services.restic.backups = mkMerge (
      flip map (attrValues config.meta.backups.storageboxes) (boxCfg: {
        "storage-box-${boxCfg.name}" = {
          hetznerStorageBox =
            let
              box = globals.hetzner.storageboxes.${boxCfg.name};
            in
            {
              enable = true;
              inherit (box) mainUser;
              inherit (box.users.${boxCfg.subuser}) subUid path;
              sshSecretName = "restic-ssh-privkey";
            };

          user = "restic";

          backupPrepareCommand = mkIf anyPostgres (
            lib.getExe (
              pkgs.writeShellApplication {
                name = "backup-postgres";
                runtimeInputs = [
                  config.services.postgresql.package
                  pkgs.util-linux
                ];
                text = ''
                  umask 0077
                  mkdir -p /var/cache/postgresql_backups
                  runuser -u postgres pg_dumpall > /var/cache/postgresql_backups/database.sql
                '';
              }
            )
          );

          paths =
            boxCfg.paths
            ++ optionals boxCfg.withPostgres [
              "/var/cache/postgresql_backups"
            ];

          timerConfig = {
            OnCalendar = "02:15";
            RandomizedDelaySec = "3h";
            Persistent = true;
          };

          initialize = true;
          passwordFile = config.age.secrets.restic-encryption-password.path;
          pruneOpts = [
            "--keep-daily 14"
            "--keep-weekly 7"
            "--keep-monthly 12"
            "--keep-yearly 75"
          ];
        };
      })
    );

    # Allow unit to read all files in the system without root
    systemd.services = mkMerge (
      flip map (attrValues config.meta.backups.storageboxes) (boxCfg: {
        "restic-backups-storage-box-${boxCfg.name}".serviceConfig.AmbientCapabilities = [
          "CAP_DAC_READ_SEARCH"
        ];
      })
    );
  };
}
