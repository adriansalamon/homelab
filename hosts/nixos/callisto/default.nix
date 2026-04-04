{
  profiles,
  ...
}:
{
  # Raspberry Pi 3B+ at Arcadia
  imports = [
    ./hardware-configuration.nix
    ./net.nix
    ./zigbee.nix
  ]
  ++ (with profiles; [
    common
    impermanence
    services.consul-client
    auto-update
  ]);

  node.site = "arcadia";

  networking.hostId = "c4736ae3";

  services.openssh.enable = true;

  # Basic monitoring
  meta.vector.enable = true;
  meta.telegraf.enable = true;

  # Don't mark as dummy so it can be deployed
  node.dummy = false;

  system.stateVersion = "25.05";
}
