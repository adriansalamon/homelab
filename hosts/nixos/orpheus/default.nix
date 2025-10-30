{ profiles, ... }:
{
  # Edge host at B22

  node.site = "erebus";

  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
    ./net.nix
    ./samba
    ./snapserver
    ./ai.nix
    ./guests.nix
  ]
  ++ (with profiles; [
    common
    zfs
    storage-users
    hardware
    impermanence
    services.consul-client
    #services.nomad.client
    services.patroni
  ]);

  networking.hostId = "fa959c4a";

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  globals.nebula.mesh.hosts.orpheus = {
    id = 2;
  };

  system.stateVersion = "24.11";
}
