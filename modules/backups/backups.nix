{
  config,
  lib,
  globals,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrValues
    flip
    mkIf
    mkMerge
    mkOption
    types
    ;
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

          user = "root";

          inherit (boxCfg) paths;
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
  };
}
