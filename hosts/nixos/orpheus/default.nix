{ profiles, ... }:
{
  # Edge host at B22

  node.site = "erebus";

  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
    ./net.nix
    ./samba
    ./ai.nix
    ./services.nix
  ]
  ++ (with profiles; [
    nixos
    zfs
    storage-users
    hardware
    impermanence
    services.consul-client
    services.seaweedfs.volume
    services.patroni
    services.victoriametrics
    auto-update
  ]);

  networking.hostId = "fa959c4a";

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  globals.nebula.mesh.hosts.orpheus = {
    id = 2;
  };

  boot.initrd.remoteUnlock = {
    enable = true;
    nebula = true;
    notify = true;
  };

  services.nomad-client = {
    enable = true;
    isMicrovm = false;
    macvlanMaster = "serverBr";
  };

  system.stateVersion = "24.11";
}
