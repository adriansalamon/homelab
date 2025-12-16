{ lib, ... }:
let
  main = "ata-INTEL_SSDSC2BB120G6K_PHWA6413013C120CGN";
  mirror = "ata-INTEL_SSDSC2BB120G6K_PHWA64130217120CGN";
in
{
  imports = [ ./disk-config.secret.nix ];

  boot.zfs.extraPools = [ "tank01" ];

  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/${main}";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
      mirror = {
        type = "disk";
        device = "/dev/disk/by-id/${mirror}";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = null;
              };
            };
            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };

    zpool = {
      zroot = lib.disk.zfs.mkZpool {
        mode = "mirror";
        datasets = lib.disk.zfs.impermanenceDatasets // {
          "safe/guests" = lib.disk.zfs.unmountable;
        };
      };

      tank01 = {
        type = "zpool";
        mountpoint = null;

        # Datasets defined in `disk-config.secret.nix`.
      };
    };
  };
}
