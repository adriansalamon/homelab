{
  config,
  globals,
  nodes,
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
    common
    zfs
    impermanence
    hardware
    services.consul-server
    services.nomad.server
    services.traefik
    services.valkey-server
    services.etcd
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
    domains = [ "delphi.site.${globals.domains.main}" ];
  };

  system.stateVersion = "25.05";
}
