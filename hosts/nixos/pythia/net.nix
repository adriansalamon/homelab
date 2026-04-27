{
  lib,
  globals,
  profiles,
  ...
}:
let
  inherit (lib)
    flip
    concatMapAttrs
    ;

  site = globals.sites.delphi;
in
{
  imports = with profiles.router; [
    common
    dhcp
    dns
    firewall-common
    nebula
    tailscale
    dyndns
  ];

  networking.hostId = "2a48ff8c";

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="c8:ff:bf:05:02:3f", NAME="wan0"
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="c8:ff:bf:05:02:3e", NAME="lan0"
  '';

  systemd.network.netdevs = flip concatMapAttrs site.vlans (
    name: vlanCfg: {
      "30-vlan-${name}" = {
        netdevConfig = {
          Kind = "vlan";
          Name = name;
        };
        vlanConfig.Id = vlanCfg.id;
      };
    }
  );

  systemd.network.networks = {
    "10-wan" = {
      matchConfig.Name = "wan0";
      DHCP = "yes";
    };

    "10-lan" = {
      matchConfig.Name = "lan0";
      linkConfig.RequiredForOnline = "carrier";
      vlan = builtins.attrNames site.vlans;
    };
  }
  // flip concatMapAttrs site.vlans (
    name: vlanCfg: {
      "30-vlan-${name}" = {
        matchConfig.Name = name;
        address = [
          (lib.net.cidr.hostCidr 1 vlanCfg.cidrv4)
        ];
      };
    }
  );

  networking.nftables = {
    enable = true;
    firewall.zones.wan.interfaces = [ "wan0" ];
  };

  globals.nebula.mesh.hosts.pythia = {
    id = 7;

    routeSubnets = [
      site.vlans.lan.cidrv4
    ];
  };
}
