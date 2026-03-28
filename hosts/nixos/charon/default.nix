{
  nodes,
  profiles,
  ...
}:
{
  # Router at Erebus
  imports = with profiles; [
    common
    zfs
    impermanence
    hardware
    auto-update
    services.consul-server
    services.nomad.server
    services.traefik
    services.valkey-server
    services.seaweedfs.master
    router.monitoring
    router.dyndns
    ./hw.nix
    ./disk-config.nix
    ./net.nix
  ];

  node.site = "erebus";

  networking.hostId = "887bb90d";

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  system.stateVersion = "25.05";
}
