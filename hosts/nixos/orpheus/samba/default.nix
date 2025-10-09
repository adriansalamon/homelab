{
  config,
  globals,
  pkgs,
  ...
}:
{

  services.samba = {
    package = pkgs.samba4;
    enable = true;
    openFirewall = true;
    settings = {
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
