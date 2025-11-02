{ pkgs, ... }:
{
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  boot.zfs.devNodes = "/dev";
  services.zfs.autoScrub.enable = true;

  environment.systemPackages = with pkgs; [
    cifs-utils
    zfs
  ];

  # After importing the rpool, rollback the root system to be empty.
  boot.initrd.systemd.services.impermanence-root = {
    wantedBy = [ "initrd.target" ];
    after = [ "zfs-import-zroot.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = "${pkgs.zfs}/bin/zfs rollback -r zroot/local/root@blank && echo '  >> >> rollback complete << <<'";
  };
}
