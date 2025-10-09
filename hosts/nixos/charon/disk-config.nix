{ lib, ... }:
let
  ssd1 = "ata-ASint_AS606_512GB_606512GHSMT25B140113";
in
{
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
    };
    zpool = {
      zroot = lib.disk.zfs.mkZpool {
        datasets = lib.disk.zfs.impermanenceDatasets;
      };
    };
  };

  meta.zrepl = {
    enable = true;
    target = "hermes";
    filesystems = {
      "zroot/safe<" = true;
    };
  };
}
