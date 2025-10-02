{ lib, ... }:
let
  ssd1 = "ata-SAMSUNG_MZ7LH480HAHQ-00005_S45PNE0M306774";
  ssd2 = "ata-SAMSUNG_MZ7LM480HMHQ-00005_S2UJNX0J404189";
in
{
  imports = [ ./disk-config.secret.nix ];

  boot.zfs.extraPools = [ "tank02" ];

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

      tank02 = {
        type = "zpool";
        mountpoint = null;

        # Datasets defined in `disk-config.secret.nix`.
      };
    };
  };
}
