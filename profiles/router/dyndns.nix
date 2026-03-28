{
  config,
  globals,
  lib,
  nodes,
  ...
}:
{
  # Dynamic dns
  age.secrets.cloudflare-dns-api-token = lib.mkIf (config.node.name != "athena") {
    inherit (nodes.athena.config.age.secrets.cloudflare-dns-api-token) rekeyFile;
  };

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.age.secrets.cloudflare-dns-api-token.path;
    domains = [ "${config.node.site}.site.${globals.domains.main}" ];
  };

  systemd.services.cloudflare-dyndns = {
    after = [
      "network-online.target"
      "coredns.service"
    ];
    requires = [ "network-online.target" ];
    wants = [ "coredns.service" ];
  };
}
