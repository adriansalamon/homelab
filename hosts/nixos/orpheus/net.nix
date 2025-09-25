{ lib, globals, ... }:
let
  inherit (lib) flip concatMapAttrs;

  vlans = {
    "lan" = 10;
    "server" = 20;
  };
in
{

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.src_valid_mark" = 1;
    "net.ipv6.conf.all.disable_ipv6" = 1;
  };

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
  }
  // flip concatMapAttrs vlans (
    name: _: {
      "30-vlan-${name}" = {
        matchConfig.Name = name;
        networkConfig = {
          DHCP = "yes";
        };
      };
    }
  );

  networking.nftables = {
    enable = true;

    firewall = {
      zones = {
        untrusted.interfaces = [
          "lan"
          "server"
          "tun-firezone"
        ];
        firezone.interfaces = [ "tun-firezone" ];
        lan.ipv4Addresses = [ globals.sites.erebus.cidrv4 ];
        olympus.ipv4Addresses = [ globals.sites.olympus.cidrv4 ];
      };

      rules = {
        masquerade-firezone = {
          from = [ "firezone" ];
          to = [ "lan" ];
          masquerade = true;
          late = true; # Only accept after any rejects have been processed
          verdict = "accept";
        };

        forward-incoming-firezone-traffic = {
          from = [ "firezone" ];
          to = [ "lan" ];
          verdict = "accept";
        };

        forward-outgoing-firezone-traffic = {
          from = [ "lan" ];
          to = [ "firezone" ];
          verdict = "accept";
        };

        forward-to-olympus = {
          from = [ "lan" ];
          to = [ "olympus" ];
          verdict = "accept";
        };

        allow-olympus-to-lan = {
          from = [ "olympus" ];
          to = [ "lan" ];
          verdict = "accept";
        };

        access-dns = {
          from = [ "lan" ];
          to = [ "local" ];
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };
      };
    };
  };
}
