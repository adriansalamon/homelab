{
  config,
  globals,
  nodes,
  ...
}:
{
  # Router at Delphi

  imports = [
    ./disk-config.nix
    ./hw.nix
    ./dns.nix
    ./net.nix
    ./traefik.nix
    ../../../config
    ../../../config/optional/zfs.nix
    ../../../config/optional/impermanence.nix
    ../../../config/optional/hardware.nix
    ../../../config/optional/consul-client.nix
  ];

  meta.vector.enable = true;
  meta.prometheus.enable = true;

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
