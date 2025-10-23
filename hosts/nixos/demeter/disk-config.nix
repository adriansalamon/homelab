{ lib, ... }:
let
  ssd1 = "ata-INTEL_SSDSC2BB120G6K_PHWA6413013C120CGN";
  ssd2 = "ata-INTEL_SSDSC2BB120G6K_PHWA64130217120CGN";
in
{
  imports = [ ./disk-config.secret.nix ];

  boot.zfs.extraPools = [ "tank01" ];

  disko.devices = {
    disk = {
      ssd1 = {
        type = "disk";
        device = "/dev/disk/by-id/${ssd1}";
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
      ssd2 = {
        type = "disk";
        device = "/dev/disk/by-id/${ssd2}";
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
        datasets = lib.disk.zfs.impermanenceDatasets;
      };

      tank01 = {
        type = "zpool";
        mountpoint = null;

        # Datasets defined in `disk-config.secret.nix`.
      };
    };
  };
}
