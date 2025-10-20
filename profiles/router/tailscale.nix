{
  config,
  nodes,
  globals,
  lib,
  ...
}:
let
  site = globals.sites.${config.node.site};
in
{
  age.secrets.headscale-auth-key = lib.mkIf (config.node.name != "athena") {
    inherit (nodes.athena.config.age.secrets.headscale-auth-key) rekeyFile;
  };

  services.tailscale = {
    enable = true;
    interfaceName = "tailscale0";
    useRoutingFeatures = "server";

    extraUpFlags = [
      "--advertise-routes=${site.vlans.lan.cidrv4}"
      "--accept-routes=false"
      "--accept-dns=false"
      "--login-server=https://headscale.${globals.domains.main}"
    ];

    authKeyFile = config.age.secrets.headscale-auth-key.path;
  };
}
