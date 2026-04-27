{
  config,
  lib,
  globals,
  profiles,
  ...
}:
let
  inherit (lib)
    optional
    singleton
    net
    flip
    concatMapAttrs
    ;

  site = globals.sites.${config.node.site};
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

  networking.hostId = "df7f09af";

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="e0:51:d8:1b:ab:e1", NAME="wan0"
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="e0:51:d8:1b:ab:e2", NAME="lan0"
  '';

  systemd.network.netdevs =
    flip concatMapAttrs site.vlans (
      name: vlanCfg: {
        "30-vlan-${name}" = {
          netdevConfig = {
            Kind = "vlan";
            Name = name;
          };
          vlanConfig.Id = vlanCfg.id;
        };
      }
    )
    // {
      # Management network for devices that don't support tagged VLANs. We use a
      # macvlan instead of assigning an IP directly to lan0, because Kea will
      # receive all frames on the parent interface. If Kea would listen on lan0,
      # it would generate duplicate DHCP offers
      "20-macvlan-mgmt" = {
        netdevConfig = {
          Kind = "macvlan";
          Name = "mgmt";
        };
        macvlanConfig.Mode = "bridge";
      };
    };

  systemd.network.networks = {
    "10-wan" = {
      matchConfig.Name = "wan0";
      DHCP = "yes";
    };

    "10-lan" = {
      matchConfig.Name = "lan0";
      linkConfig.RequiredForOnline = "carrier";
      vlan = builtins.attrNames site.vlans;
      macvlan = [ "mgmt" ];
    };

    "20-mgmt" = {
      matchConfig.Name = "mgmt";
      address = optional (site.default.cidrv4 != null) (net.cidr.hostCidr 1 site.default.cidrv4);
      linkConfig.RequiredForOnline = "routable";
    };
  }
  // flip concatMapAttrs site.vlans (
    name: vlanCfg: {
      "30-vlan-${name}" = {
        matchConfig.Name = name;
        address = [
          (net.cidr.hostCidr 1 vlanCfg.cidrv4)
        ];
      };
    }
  );

  services.kea.dhcp4.settings = {
    interfaces-config.interfaces = [ "mgmt" ];
    subnet4 = singleton {
      id = 1;
      interface = "mgmt";
      subnet = site.default.cidrv4;
      pools = [
        { pool = "${net.cidr.host 100 site.default.cidrv4} - ${net.cidr.host 200 site.default.cidrv4}"; }
      ];
      option-data = [
        {
          name = "routers";
          data = net.cidr.host 1 site.default.cidrv4;
        }
        {
          name = "domain-name-servers";
          data = net.cidr.host 1 site.default.cidrv4;
        }
      ];
    };
  };

  networking.nftables = {
    enable = true;

    firewall = {
      zones = {
        wan.interfaces = [ "wan0" ];
        extra-trusted.interfaces = [ "mgmt" ];
      };
    };
  };

  globals.nebula.mesh.hosts.${config.node.name} = {
    id = 9;

    routeSubnets = [
      site.vlans.lan.cidrv4
    ];
  };
}
