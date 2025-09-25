{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (!config.boot.isContainer) {
    boot = {
      initrd.systemd = {
        enable = true;
        emergencyAccess = config.users.users.nixos.hashedPassword;
        extraBin.ip = "${pkgs.iproute2}/bin/ip";
        extraBin.ping = "${pkgs.iputils}/bin/ping";
        extraBin.cryptsetup = "${pkgs.cryptsetup}/bin/cryptsetup";

        users.root.shell = "${pkgs.bashInteractive}/bin/bash";
        storePaths = [ "${pkgs.bashInteractive}/bin/bash" ];
      };

      kernelParams = [ "log_buf_len=16M" ]; # must be {power of two}[KMG]
      tmp.useTmpfs = true;

      loader.timeout = lib.mkDefault 2;
    };

    console.earlySetup = true;
  };
}
