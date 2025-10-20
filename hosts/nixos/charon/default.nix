{
  config,
  globals,
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
    services.consul-client
    services.traefik
    router.dhcp
    router.dns
    ./hw.nix
    ./disk-config.nix
    ./net.nix
  ];

  node.site = "erebus";

  networking.hostId = "887bb90d";

  meta.vector.enable = true;
  meta.telegraf = {
    enable = true;
    # monitor internet connectivity
    avilableMonitoringNetworks = [ "internet" ];
  };

  # Dynamic dns
  age.secrets.cloudflare-dns-api-token = {
    inherit (nodes.athena.config.age.secrets.cloudflare-dns-api-token) rekeyFile;
  };

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.age.secrets.cloudflare-dns-api-token.path;
    domains = [ "erebus.site.${globals.domains.main}" ];
  };

  system.stateVersion = "25.05";
}
