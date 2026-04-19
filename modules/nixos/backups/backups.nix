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

          paths =
            boxCfg.paths
            ++ optionals boxCfg.withPostgres [
              "/var/lib/postgresql_backups"
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
      ++ optionals anyPostgres [
        # Dump all postgres databases as the postgres user into a cache directory
        # that restic can then back up. Runs as postgres to avoid needing root or
        # CAP_SETUID in the restic service.
        {
          postgresql-dump = mkIf anyPostgres {
            description = "Dump all PostgreSQL databases for backup";
            requiredBy = map (boxCfg: "restic-backups-storage-box-${boxCfg.name}.service") (
              attrValues config.meta.backups.storageboxes
            );
            before = map (boxCfg: "restic-backups-storage-box-${boxCfg.name}.service") (
              attrValues config.meta.backups.storageboxes
            );
            after = [ "postgresql.service" ];
            requires = [ "postgresql.service" ];
            serviceConfig = {
              Type = "oneshot";
              User = "postgres";
              StateDirectory = "postgresql_backups";
              StateDirectoryMode = "0700";
              ExecStart = lib.getExe (
                pkgs.writeShellApplication {
                  name = "postgresql-dump";
                  runtimeInputs = [ config.services.postgresql.package ];
                  text = ''
                    umask 0077
                    pg_dumpall > /var/lib/postgresql_backups/database.sql
                  '';
                }
              );
            };
          };
        }
      ]
    );
  };
}
