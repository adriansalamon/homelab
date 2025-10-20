{ profiles, ... }:
{
  # Edge host at B22

  node.site = "erebus";

  imports = with profiles; [
    ./disk-config.nix
    ./hardware-configuration.nix
    ./net.nix
    ./samba
    ./snapserver
    ./ai.nix
    common
    zfs
    storage-users
    hardware
    services.consul-server
  ];

  networking.hostId = "fa959c4a";

  meta.vector.enable = true;
  meta.prometheus.enable = true;

  globals.nebula.mesh.hosts.orpheus = {
    id = 2;
  };

  system.stateVersion = "24.11";
}
