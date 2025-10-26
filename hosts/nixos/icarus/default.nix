{ profiles, ... }:
{
  imports = with profiles; [
    ./disk-config.nix
    ./hardware-configuration.nix
    ./traefik.nix
    ./headscale.nix
    ./net.nix
    common
    zfs
    impermanence
    services.consul-client
  ];

  networking.hostId = "3b1ab44f";

  globals.nebula.mesh.hosts.icarus = {
    id = 1;
    lighthouse = true;

    groups = [ "reverse-proxy" ];
  };

  meta.vector.enable = true;
  meta.telegraf = {
    enable = true;
    # monitor connectivity to external services
    avilableMonitoringNetworks = [ "external" ];
  };

  system.stateVersion = "25.05";
}
