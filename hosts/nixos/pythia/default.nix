{
  profiles,
  ...
}:
{
  # Router at Delphi
  node.site = "delphi";

  imports = with profiles; [
    ./disk-config.nix
    ./hw.nix
    ./net.nix
    nixos
    zfs
    impermanence
    hardware
    services.consul-server
    services.nomad.server
    services.traefik
    services.valkey-server
    services.seaweedfs.master
    services.vault-server
    auto-update
  ];

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  system.stateVersion = "25.05";
}
