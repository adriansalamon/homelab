# Example to create a bios compatible gpt partition
{ ... }:
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
              type = "lvm_pv";
              vg = "pool";
            };
          };
        };
      };
    };

    zpool.tank03 = {
      type = "zpool";
      mountpoint = "/mnt/tank03";

      datasets = {
        "adrian" = {
          type = "zfs_fs";
          mountpoint = "/mnt/tank03/adrian";
          options.mountpoint = "legacy";
        };
      };
    };

    lvm_vg = {
      pool = {
        type = "lvm_vg";
        lvs = {
          root = {
            size = "100%FREE";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "defaults" ];
            };
          };
        };
      };
    };
  };
}
