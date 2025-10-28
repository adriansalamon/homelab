{ lib, ... }:
let
  main = "ata-SAMSUNG_MZ7LM960HMJP-00003_S3LHNX0J710843";
  mirror = "ata-SAMSUNG_MZ7LM960HMJP-00003_S3LHNX0K502973";
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
    zpool.zroot = lib.disk.zfs.mkZpool {
      mode = "mirror";

      datasets = lib.disk.zfs.impermanenceDatasets // {
        "safe/guests" = lib.disk.zfs.unmountable;
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
