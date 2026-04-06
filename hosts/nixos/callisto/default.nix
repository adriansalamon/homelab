{ profiles, ... }:
let
  site = "arcadia";
in
{
  # Raspberry Pi 3B+ at Arcadia
  imports = [
    ./hardware-configuration.nix
    ./net.nix
    ./zigbee.nix
    ./dns.nix
  ]
  ++ (with profiles; [
    common
    impermanence
    services.consul-client
    auto-update
    services.traefik
  ]);

  node = { inherit site; };

  networking.hostId = "c4736ae3";

  # Basic monitoring
  meta.vector.enable = true;
  meta.telegraf.enable = true;

  system.stateVersion = "25.05";
}
