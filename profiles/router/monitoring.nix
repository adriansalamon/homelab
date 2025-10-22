{
  config,
  lib,
  globals,
  ...
}:
let
  siteCfg = globals.sites.${config.node.site};
  otherSites = builtins.filter (site: site != config.node.site) (builtins.attrNames globals.sites);
in
{
  meta.telegraf = {
    avilableMonitoringNetworks = [
      "internet"
    ]
    # monitor all of our vlans
    ++ lib.mapAttrsToList (name: _: "${config.node.site}-vlan-${name}") siteCfg.vlans
    # monitor all lans of other sites
    ++ map (site: "${site}-vlan-lan") otherSites;
  };
}
