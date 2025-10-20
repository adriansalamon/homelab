{
  config,
  lib,
  globals,
  nodes,
  pkgs,
  ...
}:
{

  # Ensure that all users have a nice home
  users.users = lib.genAttrs globals.users (name: {
    home = "/data/tank02/homes/${name}";
  });

  services.samba = {
    package = pkgs.samba4;
    enable = true;
    openFirewall = true;

    settings = {
      global = {
        "bind interfaces only" = "yes";
        "interfaces" = "lo ${globals.sites.olympus.vlans.lan.hosts.hermes.ipv4}";
        "workgroup" = "${globals.domains.alt}";
        "server string" = "%h";
        "security" = "user";
        "map to guest" = "bad user";
        "guest account" = "nobody";
        "invalid users" = [ "root" ];
        "logging" = "systemd";
        "store dos attributes" = "yes";
        "map hidden" = "no";
        "map system" = "no";
        "map archive" = "no";
        "inherit acls" = "yes";
        "map acl inherit" = "yes";
        "encrypt passwords" = "yes";
        "hosts allow" =
          "localhost 127.0.0.1 ${nodes.icarus.config.services.headscale.settings.prefixes.v4} ${
            lib.concatMapAttrsStringSep " " (_: siteCfg: siteCfg.vlans.lan.cidrv4) globals.sites
          }";
        "hosts deny" = "0.0.0.0/0";
      };

      homes = {
        browseable = "no";
        "guest ok" = "no";
        "read only" = "no";
        "create mask" = "0770";
        "directory mask" = "0770";
      };

      shared = {
        "path" = "/data/tank02/shared";
        browseable = "yes";
        "guest ok" = "no";
        "read only" = "no";
        "create mask" = "0664";
        "directory mask" = "2775";
        "force group" = "salamon";
        "valid users" = "@salamon";
      };

      media = {
        "path" = "/data/tank02/media";
        "browseable" = "yes";
        "read only" = "yes";
        "write list" = "adrian";
        "valid users" = "@salamon";
        "force group" = "media";
      };

      scanning = {
        "path" = "/data/tank02/shared/scanning";
        browseable = "yes";
        "guest ok" = "yes";
        "read only" = "no";
        "create mask" = "0664";
        "directory mask" = "2775";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  age.secrets = lib.genAttrs' globals.users (name: {
    name = "${name}-smb-password";
    value.generator.script = "passphrase";
  });

  system.activationScripts.samba-init-passwords.text = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (user: secretPath: ''
      if [ -f ${secretPath} ]; then
          echo "Setting smb password for ${user}"
          smb_pass=$(cat ${secretPath})
          echo -e "$smb_pass\n$smb_pass" | ${config.services.samba.package}/bin/smbpasswd -s -a ${user}
          rm ${secretPath} # clean up, we don't need it anymore
      fi
    '') (lib.genAttrs globals.users (name: config.age.secrets."${name}-smb-password".path))
  );

  consul.services."hermes-files" = {
    address = globals.sites.olympus.vlans.lan.hosts.hermes.ipv4;
    port = 445;
    tags = [ "kea-ddns" ]; # hack to make hermes-files.internal to resolve here
  };
}
