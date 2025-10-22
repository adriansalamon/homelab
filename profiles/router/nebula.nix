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
    groups = [ "router" ];

    routeSubnets = [
      site.vlans.lan.cidrv4
    ];

    config.settings = {
      # We do our own routing below, setting the src to be
      # able to use this route for the router itself
      tun.use_system_route_table = true;
      tun.unsafe_routes = mapAttrsToList (hostName: hostCfg: {
        route = builtins.head hostCfg.routeSubnets;
        via = hostCfg.ipv4;
        install = false;
      }) otherRouters;
    };

    firewall.inbound = [
      {
        port = "any";
        proto = "any";
        local_cidr = site.vlans.lan.cidrv4;
        group = "router";
      }
    ]
    ++ mapAttrsToList (hostName: hostCfg: {
      port = "any";
      proto = "any";
      cidr = builtins.head hostCfg.routeSubnets;
      local_cidr = site.vlans.lan.cidrv4;
    }) otherRouters;
  };

  systemd.network.networks."50-nebula-mesh" = {
    matchConfig.Name = "nebula.mesh";
    addresses = [
      {
        Address =
          lib.net.cidr.withCidr globals.nebula.mesh.hosts.${config.node.name}.ipv4
            globals.nebula.mesh.cidrv4;
        Broadcast = "false";
      }
    ];
    linkConfig = {
      MTUBytes = 1300;
    };
    routes = mapAttrsToList (hostName: hostCfg: {
      # assume that the first subnet is to be routed
      Destination = builtins.head hostCfg.routeSubnets;
      # set source to be the lan addres of the router, so that
      # routers can route to each other
      PreferredSource = lib.net.cidr.host 1 site.vlans.lan.cidrv4;
      Scope = "link";
    }) otherRouters;
  };
}
