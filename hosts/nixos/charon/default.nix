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
    services.consul-server
    services.nomad.server
    services.traefik
    services.valkey-server
    router.monitoring
    ./hw.nix
    ./disk-config.nix
    ./net.nix
  ];

  node.site = "erebus";

  networking.hostId = "887bb90d";

  meta.vector.enable = true;
  meta.telegraf.enable = true;

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
