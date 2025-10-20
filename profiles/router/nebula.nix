{
  config,
  globals,
  lib,
  ...
}:
let
  inherit (lib)
    mapAttrsToList
    filterAttrs
    ;

  site = globals.sites.${config.node.site};

  otherRouters = filterAttrs (
    hostName: hostCfg: hostName != config.node.name && hostCfg.routeSubnets != [ ]
  ) globals.nebula.mesh.hosts;
in
{

  globals.nebula.mesh.hosts.${config.node.name} = {
    routeSubnets = [
      site.vlans.lan.cidrv4
    ];

    config.settings = {
      tun.unsafe_routes = mapAttrsToList (hostName: hostCfg: {
        route = builtins.head hostCfg.routeSubnets;
        via = hostCfg.ipv4;
      }) otherRouters;
    };

    firewall.inbound = mapAttrsToList (hostName: hostCfg: {
      port = "any";
      proto = "any";
      cidr = builtins.head hostCfg.routeSubnets;
      local_cidr = site.vlans.lan.cidrv4;
    }) otherRouters;
  };
}
