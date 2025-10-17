{
  config,
  globals,
  pkgs,
  lib,
  ...
}:
{

  services.samba = {
    package = pkgs.samba4;
    enable = true;
    openFirewall = true;
    settings = {

      global = {
        "bind interfaces only" = "yes";
        "interfaces" = "lo ${globals.sites.erebus.vlans.lan.hosts.orpheus.ipv4}";
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
        "hosts allow" = "localhost 127.0.0.1 100.64.0.0/10 ${
          lib.concatMapAttrsStringSep " " (_: siteCfg: siteCfg.vlans.lan.cidrv4) globals.sites
        }";
        "hosts deny" = "0.0.0.0/0";
      };

      server = {
        "min protocol" = "SMB3_00";
        "smb encrypt" = "required";
      };

      "adrian" = {
        path = "/mnt/tank03/adrian/";
        "browseable" = "yes";
        "writable" = "yes";
        "guest ok" = "no";
        "read only" = "no";
      };

      "media" = {
        path = "/mnt/tank03/media/";
        "browseable" = "yes";
        "writable" = "yes";
        "guest ok" = "no";
        "read only" = "no";
      };
    };
  };

  age.secrets."adrian-smb-password" = {
    generator.script = "passphrase";
  };

  system.activationScripts.samba-init-passwords.text =
    let
      secretPath = config.age.secrets."adrian-smb-password".path;
      user = "adrian";
    in
    ''
      if [ -f ${secretPath} ]; then
          echo "Setting smb password for ${user}"
          smb_pass=$(cat ${secretPath})
          echo -e "$smb_pass\n$smb_pass" | ${config.services.samba.package}/bin/smbpasswd -s -a ${user}
          rm ${secretPath} # clean up, we don't need it anymore
      fi
    '';

  consul.services."orpheus-files" = {
    address = globals.sites.erebus.vlans.lan.hosts.orpheus.ipv4;
    port = 445;
    tags = [ "kea-ddns" ]; # hack to make orpheus-files.internal to resolve here
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  services.avahi = {
    publish.enable = true;
    publish.userServices = true;
    enable = true;
    openFirewall = true;
  };
}
