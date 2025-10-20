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
  imports = [
    profiles.router.firewall-common
    profiles.router.nebula
    profiles.router.tailscale
    profiles.router.common
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

      address = lib.optional (site.default.cidrv4 != null) (lib.net.cidr.hostCidr 1 site.default.cidrv4);
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

    firewall = {
      zones = {
        wan.interfaces = [ "wan0" ];
        lan.interfaces = [ "lan0" ];
      };
    };
  };

  globals.nebula.mesh.hosts.pythia = {
    id = 7;

    routeSubnets = [
      site.vlans.lan.cidrv4
    ];

    groups = [
      "reverse-proxy"
    ];
  };
}
