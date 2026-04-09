{ lib, ... }:
{
  disko.devices = {
    disk.main = {
      device = "/dev/disk/by-id/nvme-KINGSTON_SNV2S500G_50026B7381B6CFE2";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          # BIOS boot partition
          boot = {
            name = "boot";
            size = "1M";
            type = "EF02";
          };

          esp = {
            name = "ESP";
            size = "1G";
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

    # ZFS root pool with impermanence datasets
    zpool.zroot = lib.disk.zfs.mkZpool {
      datasets = lib.disk.zfs.impermanenceDatasets // {
        # Additional datasets for desktop-specific needs
        "safe/home" = lib.disk.zfs.filesystem "/home";
      };
    };
  };

  # Mark /home filesystem as needed for boot (required by impermanence)
  fileSystems."/home".neededForBoot = true;

  # Enable home-manager persistence
  # User-specific persistence is configured in users/asalamon/nixos/default.nix
  programs.fuse.userAllowOther = true; # Required for home-manager persistence
}
