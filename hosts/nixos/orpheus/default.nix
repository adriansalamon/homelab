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
    ./homepage.nix
    ./ai.nix
    ./db.nix
    common
    zfs
    storage-users
    hardware
    services.consul-client
    services.nomad.client
  ];

  networking.hostId = "fa959c4a";

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  globals.nebula.mesh.hosts.orpheus = {
    id = 2;
  };

  system.stateVersion = "24.11";
}
