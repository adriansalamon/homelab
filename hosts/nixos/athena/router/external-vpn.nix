{
  config,
  pkgs,
  globals,
  ...
}:
let
  site = globals.sites.olympus;
in
{

  age.secrets = {
    vpn-private-key = {
      rekeyFile = ../secrets/vpn-private-key.txt.age;
      owner = "systemd-network";
    };
    vpn-psk = {
      rekeyFile = ../secrets/vpn-psk.txt.age;
      owner = "systemd-network";
    };
  };

  environment.systemPackages = [ pkgs.wireguard-tools ];
  boot.kernelModules = [ "wireguard" ];

  systemd.network = {
    networks."50-external-vpn" = {
      matchConfig.Name = "external-vpn";
      networkConfig = {
        Address = site.vlans.external-vpn.cidrv4;
        DHCP = "no";
        IPv6PrivacyExtensions = "kernel";
      };

      routingPolicyRules = [
        {
          IncomingInterface = "external-vpn";
          Table = "1000";
          Priority = 20;
        }
        {
          IncomingInterface = "external-vpn";
          To = site.vlans.server.cidrv4;
          Priority = 15;
        }
      ];
    };

    netdevs."50-wg0" = {
      netdevConfig = {
        Kind = "wireguard";
        Name = "wg0";
        MTUBytes = "1320";
      };
      wireguardConfig = {
        PrivateKeyFile = config.age.secrets.vpn-private-key.path;
        ListenPort = 52540;
      };
      wireguardPeers = [
        {
          PublicKey = "PyLCXAQT8KkM4T+dUsOQfn+Ub3pGxfGlxkIApuig+hk=";
          PresharedKeyFile = config.age.secrets.vpn-psk.path;
          AllowedIPs = "0.0.0.0/0";
          Endpoint = "37.46.199.52:1637"; # ashlesha
          RouteTable = "1000";
          PersistentKeepalive = 15;
        }
      ];
    };

    networks."50-wg0" = {
      matchConfig.Name = "wg0";
      networkConfig = {
        Address = site.airvpn.local-cidrv4;
        DNS = "10.128.0.1";
      };
      routingPolicyRules = [
        {
          To = "10.128.0.0/24";
          Table = "1000";
          Priority = 30;
        }
      ];
    };
  };

}
