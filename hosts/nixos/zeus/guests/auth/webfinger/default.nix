{ pkgs, globals, ... }:
let
  port = 9090;
  webfingerServer = pkgs.callPackage ./webfinger.nix { };
in
{

  systemd.services.webfinger-server = {
    description = "WebFinger Server for ${globals.domains.alt}";
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = "${webfingerServer}/bin/webfinger";
      Restart = "always";

    };

    environment = {
      "DOMAIN" = globals.domains.alt;
      "ADDR" = ":${toString port}";
    };
  };

  consul.services.webfinger-server = {
    inherit port;
    tags = [
      "traefik.enable=true"
      "traefik.external=true"
      "traefik.http.routers.webfinger.rule=Host(`${globals.domains.alt}`) && PathPrefix(`/.well-known/webfinger`)"
      "traefik.http.routers.webfinger.entrypoints=websecure"
    ];
  };

  globals.nebula.mesh.hosts.zeus-auth.firewall.inbound = [
    {
      port = builtins.toString port;
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];
}
