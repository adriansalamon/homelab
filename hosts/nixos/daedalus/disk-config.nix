{ lib, ... }:
let
  disk = "/dev/sda";
in
{
  disko.devices = {
    disk.disk1 = {
      device = disk;
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

    zpool.zroot = lib.disk.zfs.mkZpool {
      datasets = lib.disk.zfs.encryptedImpermanenceDatasets {
        encryption = "aes-256-gcm";
        keyformat = "passphrase";
        keylocation = "prompt";
      };
    };
  };

  boot.loader.grub = {
    enable = true;
    efiSupport = false;
  };
}
