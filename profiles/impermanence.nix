{ lib, config, ... }:
let
  inherit (lib)
    optionals
    ;
in
{
  age.identityPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];

  # Important, but not critical. Does not need to be backed up.
  fileSystems."/state".neededForBoot = true;
  environment.persistence."/state" = {
    hideMounts = true;
    directories = [
      "/var/lib/systemd"
      "/var/log"
      "/var/spool"
    ];
  };

  # Persistent data. Backup this.
  fileSystems."/persist".neededForBoot = true;
  environment.persistence."/persist" = {
    hideMounts = true;
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
    directories = [
      "/var/lib/nixos"
    ]
    ++ optionals config.services.postgresql.enable [
      {
        directory = "/var/lib/postgresql";
        user = "postgres";
        group = "postgres";
        mode = "0700";
      }
    ];
  };
}
