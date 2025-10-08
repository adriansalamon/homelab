{ globals, lib, ... }:
let
  inherit (lib)
    flip
    concatMapAttrs
    ;
  site = globals.sites.olympus;

  vlans = lib.keepAttrs site.vlans [
    "lan"
    "server"
  ];
in
{
  networking.nftables.enable = true;

  networking.useNetworkd = true;
  systemd.network.enable = true;

  systemd.network.netdevs = {
    "20-bond0" = {
      netdevConfig = {
        Kind = "bond";
        Name = "bond0";
      };
      bondConfig = {
        Mode = "802.3ad";
      };
    };
  }
  // flip concatMapAttrs vlans (
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
    "10-physical" = {
      matchConfig.Name = [
        "enp1s0f0"
        "enp1s0f1"
      ];
      networkConfig.Bond = "bond0";
    };

    "20-bond0" = {
      matchConfig.Name = "bond0";
      networkConfig = {
        DHCP = "no";
        VLAN = builtins.attrNames vlans;
      };
    };

    "30-vlan-lan" = {
      matchConfig.Name = "lan";
      networkConfig = {
        DHCP = "no";
        Address = site.vlans.lan.hosts.hermes.cidrv4; # Static IP here
      };
    };

    "30-vlan-server" = {
      matchConfig.Name = "server";
      networkConfig = {
        DHCP = "yes";
      };
    };
  };

  networking.nftables.firewall.zones.untrusted.interfaces = builtins.attrNames vlans;
}
