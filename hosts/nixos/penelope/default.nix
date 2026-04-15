{
  profiles,
  ...
}:
{
  # Router at Ithaca
  node.site = "ithaca";

  imports = with profiles; [
    ./disk-config.nix
    ./hw.nix
    ./net.nix
    nixos
    zfs
    impermanence
    hardware
    services.consul-client
    services.traefik
    auto-update
  ];

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  system.stateVersion = "25.05";
}
