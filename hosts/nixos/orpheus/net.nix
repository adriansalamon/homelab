{ lib, globals, ... }:
let
  inherit (lib) flip concatMapAttrs;

  site = globals.sites.erebus;

  vlans = {
    "lan" = 10;
    "server" = 20;
  };
in
{
  networking.useNetworkd = true;
  systemd.network.enable = true;

  systemd.network.netdevs = flip concatMapAttrs vlans (
    name: id: {
      "30-vlan-${name}" = {
        netdevConfig = {
          Kind = "vlan";
          Name = name;
        };
        vlanConfig.Id = id;
      };
    }
  );

  systemd.network.networks = {
    "10-physical" = {
      matchConfig.Name = "enp2s0";
      networkConfig = {
        VLAN = builtins.attrNames vlans;
        DHCP = "no";
      };
    };

    "30-vlan-lan" = {
      matchConfig.Name = "lan";
      networkConfig = {
        DHCP = "no";
        Address = site.vlans.lan.hosts.orpheus.cidrv4; # Static IP here
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
