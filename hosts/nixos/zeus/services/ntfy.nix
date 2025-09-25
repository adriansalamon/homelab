{ globals, ... }:
let
  port = 8083;
in
{

  services.ntfy-sh = {
    enable = true;
    settings = {
      base-url = "https://ntfy.local.${globals.domains.main}";
      listen-http = ":${toString port}";
    };
  };

  consul.services.ntfy = {
    inherit port;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.ntfy.rule=Host(`ntfy.local.${globals.domains.main}`)"
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
