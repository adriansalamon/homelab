{ lib, ... }:
{
  disko.devices = {
    disk.disk1 = {
      device = "/dev/disk/by-id/nvme-Samsung_SSD_980_500GB_S64DNX0T339019F";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "boot";
            size = "1M";
            type = "EF02";
          };
          esp = {
            name = "ESP";
            size = "500M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          root = {
            name = "root";
            size = "100%";
            content = {
              type = "zfs";
              pool = "zroot";
            };
          };
        };
      };
    };

    zpool.tank03 = {
      type = "zpool";
      mountpoint = null;

      datasets = {
        "adrian" = {
          type = "zfs_fs";
          mountpoint = "/data/tank03/adrian";
          options.mountpoint = "legacy";
        };

        "media" = {
          type = "zfs_fs";
          mountpoint = "/data/tank03/media";
          options.mountpoint = "legacy";
        };
      };
    };

    zpool.zroot = lib.disk.zfs.mkZpool {
      datasets = lib.disk.zfs.impermanenceDatasets // {
        "safe/guests" = lib.disk.zfs.unmountable;
        "safe/seaweedfs" = lib.disk.zfs.filesystem "/data/seaweedfs";
      };
    };
  };

  meta.zrepl = {
    enable = true;
    target = "hermes";
    filesystems = {
      "tank03/adrian" = true;
    };
  };

  meta.backups.storageboxes."cloud-backups" = {
    subuser = "orpheus-files";
    paths = [ "/data/tank03/adrian/" ];
  };
}
