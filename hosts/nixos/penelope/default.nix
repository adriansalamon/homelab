{
  config,
  globals,
  nodes,
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
    common
    zfs
    impermanence
    hardware
    services.consul-client
    services.traefik
  ];

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  # Dynamic dns
  age.secrets.cloudflare-dns-api-token = {
    inherit (nodes.athena.config.age.secrets.cloudflare-dns-api-token) rekeyFile;
  };

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.age.secrets.cloudflare-dns-api-token.path;
    domains = [ "${config.node.site}.site.${globals.domains.main}" ];
  };

  system.stateVersion = "25.05";
}
