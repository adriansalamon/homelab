{
  config,
  globals,
  nodes,
  pkgs,
  lib,
  ...
}:
let
  port = 3000;
  format = pkgs.formats.toml { };

  nodeNames = lib.mapAttrsToList (name: _: { inherit name; }) (
    lib.filterAttrs (_: hostCfg: !hostCfg.config.node.guest) nodes
  );
  nodesFile = format.generate "nodes.toml" { nodes = nodeNames; };
in
{

  # Includes
  # - CONSUL_HTTP_TOKEN
  # - JELLYFIN_TOKEN
  age.secrets."homepage.env" = {
    rekeyFile = config.node.secretsDir + "/homepage.env.age";
  };

  systemd.services.homepage = {
    description = "Homepage";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 10;

      EnvironmentFile = config.age.secrets."homepage.env".path;
      ExecStart = lib.getExe pkgs.homepage;
    };

    environment = {
      "PUBLIC_DOMAIN" = globals.domains.main;
      "PUBLIC_LOCAL_DOMAIN" = "local.${globals.domains.main}";
      "JELLYFIN_URL" = "https://jellyfin.${globals.domains.main}";
      "CONSUL_HTTP_ADDR" = "http://127.0.0.1:8500";
      "NODES_FILE" = nodesFile;
    };
  };

  consul.services.homepage = {
    inherit port;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.homepage.rule=Host(`home.${globals.domains.main}`) || Host(`home.local.${globals.domains.main}`)"
      "traefik.http.routers.homepage.middlewares=authelia"
    ];
  };

  globals.nebula.mesh.hosts.${config.node.name}.firewall.inbound = lib.singleton {
    inherit port;
    proto = "tcp";
    group = "reverse-proxy";
  };
}
