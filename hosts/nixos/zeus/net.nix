{ lib, ... }:
let
  inherit (lib) flip concatMapAttrs;

  vlans = {
    lan = 10;
    server = 20;
    vpn = 22;
  };
in
{

  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.netdevs = {
    "10-bond0" = {
      netdevConfig = {
        Kind = "bond";
        Name = "bond0";
      };
      bondConfig = {
        Mode = "active-backup";
      };
    };
  }
  // flip concatMapAttrs vlans (
    vlan: id: {
      "20-${vlan}" = {
        netdevConfig = {
          Kind = "vlan";
          Name = vlan;
        };
        vlanConfig.Id = id;
      };

      "30-${vlan}Br" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "${vlan}Br";
        };
      };
    }
  );

  systemd.network.networks = {
    "10-physical" = {
      matchConfig.Name = [
        "ens1f0np0"
        "ens1f1np1"
      ];
      networkConfig.Bond = "bond0";
    };

    "10-bond0" = {
      matchConfig.Name = [ "bond0" ];
      networkConfig = {
        VLAN = builtins.attrNames vlans;
        DHCP = "no";
      };
    };
  }
  // flip concatMapAttrs vlans (
    vlan: id: {
      "20-${vlan}" = {
        matchConfig.Name = vlan;
        networkConfig = {
          Bridge = "${vlan}Br";
        };
      };

      "${vlan}Br" = {
        matchConfig.Name = "${vlan}Br";
        networkConfig = {
          DHCP = if vlan == "server" then "yes" else "no";
        };
      };
    }
  );

  networking.nftables.firewall.zones.untrusted.interfaces = [ "serverBr" ];
}
