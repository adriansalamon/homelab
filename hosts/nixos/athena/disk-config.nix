{ lib, ... }:
let
  main = "ata-INTEL_SSDSC2BB120G6K_PHWA638100EE120CGN";
  mirror = "ata-INTEL_SSDSC2BB120G6K_PHWA640200HG120CGN";
in
{
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

        # TODO: take a proper zfs zroot/local/root@blank snapshot
        datasets = lib.disk.zfs.impermanenceDatasets;
      };
    };
  };
}
