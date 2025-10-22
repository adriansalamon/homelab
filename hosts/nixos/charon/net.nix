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

  site = globals.sites.erebus;
in
{
  imports = with profiles.router; [
    common
    dhcp
    dns
    firewall-common
    nebula
    tailscale
  ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="c8:ff:bf:04:fe:d9", NAME="wan0"
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="c8:ff:bf:04:fe:d8", NAME="lan0"
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

  networking.nftables.firewall = {
    zones = {
      wan.interfaces = [ "wan0" ];
    };
  };

  globals.nebula.mesh.hosts.charon = {
    id = 6;
  };
}
