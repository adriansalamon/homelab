{ lib, ... }:
let
  ssd1 = "ata-TWSC_TSC10N512-H6Q10S_TTSMA253KX04106";
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
}
