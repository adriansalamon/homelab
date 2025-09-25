{ globals, ... }:
let
  port = 8082;
in
{
  services.homepage-dashboard = {
    enable = true;
    listenPort = port;
  };

  consul.services.homepage = {
    inherit port;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.homepage.rule=Host(`homepage.local.${globals.domains.main}`)"
      "traefik.http.routers.homepage.middlewares=authelia"
    ];
  };

  globals.nebula.mesh.hosts.zeus.firewall.inbound = [
    {
      port = builtins.toString port;
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];
}
