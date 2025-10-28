{ ... }:
{

  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network = {
    netdevs."10-bond0" = {
      netdevConfig = {
        Kind = "bond";
        Name = "bond0";
      };
      bondConfig = {
        Mode = "active-backup";
      };
    };

    networks."10-physical" = {
      matchConfig.Name = [
        "ens1f0np0"
        "ens1f1np1"
      ];
      networkConfig.Bond = "bond0";
    };

    networks."10-bond0" = {
      matchConfig.Name = [ "bond0" ];
      networkConfig = {
        VLAN = [
          "server"
          "vpn"
        ];
        DHCP = "no";
      };
    };

    netdevs."20-server" = {
      netdevConfig = {
        Name = "server";
        Kind = "vlan";
      };
      vlanConfig.Id = 20;
    };

    netdevs."20-vpn" = {
      netdevConfig = {
        Name = "vpn";
        Kind = "vlan";
      };
      vlanConfig.Id = 22;
    };

    networks."20-server" = {
      matchConfig.Name = "server";
      networkConfig = {
        Bridge = "serverBr";
      };
    };

    networks."20-vpn" = {
      matchConfig.Name = "vpn";
      networkConfig = {
        Bridge = "vpnBr";
      };
    };

    netdevs."30-serverBr" = {
      netdevConfig = {
        Name = "serverBr";
        Kind = "bridge";
      };
    };

    networks."30-serverBr" = {
      matchConfig.Name = "serverBr";
      networkConfig = {
        DHCP = "yes";
      };
    };

    netdevs."30-vpnBr" = {
      netdevConfig = {
        Name = "vpnBr";
        Kind = "bridge";
      };
    };

    networks."30-vpnBr" = {
      matchConfig.Name = "vpnBr";
      networkConfig = {
        DHCP = "no";
      };
    };
  };

  networking.nftables.firewall.zones.untrusted.interfaces = [ "serverBr" ];
}
