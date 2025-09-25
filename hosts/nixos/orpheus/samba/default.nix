{ pkgs, ... }:
{

  users.extraUsers.asalamon = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
  };

  services.samba = {
    package = pkgs.samba4Full;
    enable = true;
    openFirewall = true;
    settings = {
      server = {
        "min protocol" = "SMB3_00";
        "smb encrypt" = "required";
      };

      "adrian" = {
        path = "/mnt/tank03/ds03/adrian/";
        "force user" = "asalamon";
        "browseable" = "yes";
        "writable" = "yes";
        "guest ok" = "no";
        "read only" = "no";
      };
    };
  };

  systemd.tmpfiles.rules = [ "d /mnt/tank03/ds03/adrian 0755 asalamon users -" ];

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
