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

  systemd.network.netdevs =
    (flip concatMapAttrs vlans (
      name: id: {
        "30-vlan-${name}" = {
          netdevConfig = {
            Kind = "vlan";
            Name = name;
          };
          vlanConfig.Id = id;
        };
      }
    ))
    // {
      "40-serverBr" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "serverBr";
        };
      };
    };

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
        DHCP = "no";
        Bridge = "serverBr";
      };
    };

    "40-serverBr" = {
      matchConfig.Name = "serverBr";
      networkConfig = {
        DHCP = "yes";
      };
    };
  };

  # initrd needs its own network config — runtime systemd.network is not carried over.
  # Use server VLAN (20) with DHCP directly — no bridge needed in initrd.
  boot.initrd.availableKernelModules = [ "8021q" ];
  boot.initrd.systemd.network = {
    netdevs."30-server" = {
      netdevConfig = {
        Kind = "vlan";
        Name = "server";
      };
      vlanConfig.Id = 20;
    };
    networks."10-physical" = {
      matchConfig.Name = "enp2s0";
      networkConfig = {
        VLAN = [ "server" ];
        DHCP = "no";
      };
    };
    networks."30-server" = {
      matchConfig.Name = "server";
      networkConfig.DHCP = "yes";
    };
  };

  networking.nftables.firewall.zones.untrusted.interfaces = (builtins.attrNames vlans) ++ [
    "serverBr"
  ];
}
