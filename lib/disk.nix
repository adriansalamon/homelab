_inputs: final: prev: {
  lib = prev.lib // {
    disk = {
      zfs = rec {
        mkZpool = prev.lib.recursiveUpdate {
          type = "zpool";
          options = {
            ashift = "12";
            autotrim = "on";
          };
          rootFsOptions = {
            acltype = "posixacl";
            canmount = "off";
            compression = "zstd";
            dnodesize = "auto";
            normalization = "formD";
            mountpoint = "none";
            relatime = "on";
            devices = "off";
            xattr = "sa";
            "com.sun:auto-snapshot" = "false";
          };
        };

        impermanenceDatasets = {
          "local" = unmountable;
          "local/root" = filesystem "/" // {
            postCreateHook = "zfs snapshot zroot/local/root@blank";
          };
          "local/nix" = filesystem "/nix";
          "local/state" = filesystem "/state";
          "safe" = unmountable;
          "safe/persist" = filesystem "/persist";
        };

        unmountable = {
          type = "zfs_fs";
          options.mountpoint = "none";
        };

        filesystem = mountpoint: {
          type = "zfs_fs";
          options.mountpoint = "legacy";
          inherit mountpoint;
        };
      };
    };
  };
}
