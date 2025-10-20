{ lib, config, ... }:
let
  inherit (lib)
    flatten
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    optional
    types
    unique
    pipe
    ;
in
{
  options.services.restic.backups = mkOption {
    type = types.attrsOf (
      types.submodule (submod: {
        options.hetznerStorageBox = {
          enable = mkEnableOption "Configure this backup to backup to Hetzner Storage Box via sftp";

          mainUser = mkOption {
            type = types.str;
            description = "The main username for this storage box";
          };

          subUid = mkOption {
            type = types.int;
            description = "The id of the subuser that was allocated on the hetzner server for this backup.";
          };

          path = mkOption {
            type = types.str;
            description = "The remote path to backup to";
          };

          sshSecretName = mkOption {
            type = types.str;
            description = "The age secret name for the ssh key to use to login";
          };
        };

        config =
          let
            subuser = "${submod.config.hetznerStorageBox.mainUser}-sub${toString submod.config.hetznerStorageBox.subUid}";
            url = "${subuser}@${submod.config.hetznerStorageBox.mainUser}.your-storagebox.de";
            identityFile = config.age.secrets.${submod.config.hetznerStorageBox.sshSecretName}.path;
          in
          mkIf submod.config.hetznerStorageBox.enable {
            repository = "rclone:";
            extraOptions = [
              "rclone.program='ssh -p23 ${url} -i ${identityFile}'"
            ];
          };
      })
    );
  };

  config.services.openssh.knownHosts.hetzner-storage-boxes =
    let
      names = pipe config.services.restic.backups [
        (mapAttrsToList (
          _: cfg:
          optional cfg.hetznerStorageBox.enable "[${cfg.hetznerStorageBox.mainUser}.your-storagebox.de]:23"
        ))
        flatten
        unique
      ];
    in
    mkIf (names != [ ]) {
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
      hostNames = names;
    };
}
