{
  config,
  lib,
  globals,
  ...
}:
let
  inherit (lib)
    mkOption
    mkIf
    types
    attrValues
    flip
    ;

  cfg = config.backups;
in
{

  options.backups = mkOption {
    description = "Module to configure Nomad backup jobs to Hetzner Storage Boxes";
    default = { };
    type = types.attrsOf (
      types.submodule (submod: {
        options = {
          name = mkOption {
            description = "The name of the backup job. Defaults to the attribute name.";
            default = submod.config._module.args.name;
            type = types.str;
          };

          storageBox = mkOption {
            description = "The name of the storage box to backup to. The box must be defined in the globals.";
            type = types.str;
            default = "cloud-backups";
          };

          subuser = mkOption {
            description = "The name of the subuser. Must be defined in the globals.";
            type = types.str;
          };
        };
      })
    );
  };

  config = mkIf (cfg != { }) {
    # Generate restic encryption passwords for each backup job
    nomadJobs = lib.mkMerge (
      flip map (attrValues cfg) (backupCfg: {
        "backup-${backupCfg.name}" = {
          secrets = {
            ssh-private-key.generator.script =
              {
                lib,
                name,
                pkgs,
                ...
              }:
              ''
                TMPFILE=$(mktemp)
                ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -C ${lib.escapeShellArg "${name}"} -f "$TMPFILE" <<<y >/dev/null 2>&1
                cat "$TMPFILE"
                rm "$TMPFILE" "$TMPFILE.pub"
              '';

            restic-password.generator.script = "alnum";
          };
        };
      })
    );
  };
}
