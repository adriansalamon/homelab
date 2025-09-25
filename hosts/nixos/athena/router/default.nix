{
  config,
  globals,
  lib,
  ...
}:
let
  site = globals.sites.olympus;

  # extract all hosts from all vlans
  hosts = builtins.foldl' (acc: vlan: acc // vlan.hosts) { } (builtins.attrValues site.vlans);

  airvpn-port = toString site.airvpn.port;

  inherit (lib)
    net
    flip
    concatMapAttrs
    mapAttrsToList
    ;
in
{
  imports = [
    ./external-vpn.nix
    ./dns.nix
  ];

  boot.kernel.sysctl = {
    # we are a router, yay!
    "net.ipv4.ip_forward" = 1;

    # Connection tracking table size
    "net.netfilter.nf_conntrack_max" = 262144;

    # Apparently we need ipv6 for wireguard to even work
    "net.ipv6.conf.all.disable_ipv6" = 0;
    "net.ipv6.conf.default.disable_ipv6" = 0;

    # Basic TCP optimizations
    "net.ipv4.tcp_window_scaling" = 1;
    "net.ipv4.tcp_sack" = 1;
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="d4:ae:52:d2:31:5f", NAME="wan0"
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="d4:ae:52:d2:31:60", NAME="lan2"
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:36:9f:14:30:58", NAME="lan0"
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="a0:36:9f:14:30:5a", NAME="lan1"
  '';

  networking = {
    useDHCP = false;
    usePredictableInterfaceNames = false;
    useNetworkd = true;
    resolvconf.enable = false;
  };

  systemd.network.enable = true;
  systemd.network.wait-online.enable = false;

  systemd.network.netdevs = {
    "20-bond0" = {
      netdevConfig = {
        Kind = "bond";
        Name = "bond0";
      };
      bondConfig = {
        Mode = "802.3ad";
        TransmitHashPolicy = "layer3+4";
        MIIMonitorSec = "1s";
        LACPTransmitRate = "fast";
      };
    };

    "40-br0" = {
      netdevConfig = {
        Kind = "bridge";
        Name = "br0";
      };
    };
  }
  // flip concatMapAttrs site.vlans (
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
    "30-bond0" = {
      matchConfig.Name = "bond0";
      networkConfig = {
        BindCarrier = "lan0 lan1";
        Bridge = "br0";
        DHCP = "no";
        IPv6PrivacyExtensions = "kernel";
      };
    };
    "30-lan0" = {
      matchConfig.Name = "lan0";
      networkConfig = {
        Bond = "bond0";
      };
    };
    "30-lan1" = {
      matchConfig.Name = "lan1";
      networkConfig = {
        Bond = "bond0";
      };
    };
    "30-lan2" = {
      matchConfig.Name = "lan2";
      networkConfig = {
        Bridge = "br0";
      };
    };
    "40-br0" = {
      matchConfig.Name = "br0";
      networkConfig = {
        DHCP = "no";
        IPv6PrivacyExtensions = "kernel";
        VLAN = builtins.attrNames site.vlans;
      };
    };
    "40-wan0" = {
      matchConfig.Name = "wan0";
      networkConfig = {
        DHCP = "yes";
      };
    };
  }
  // flip concatMapAttrs site.vlans (
    name: vlanCfg: {
      "40-vlan-${name}" = {
        matchConfig.Name = name;
        address = [
          (lib.net.cidr.hostCidr 1 vlanCfg.cidrv4)
        ];
      };
    }
  );

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config = {
        interfaces = flip mapAttrsToList site.vlans (name: _: name);
      };

      subnet4 = flip mapAttrsToList site.vlans (
        name: vlanCfg: {
          inherit (vlanCfg) id;
          subnet = vlanCfg.cidrv4;
          pools = [ { pool = "${net.cidr.host 100 vlanCfg.cidrv4} - ${net.cidr.host 200 vlanCfg.cidrv4}"; } ];

          option-data = [
            {
              name = "routers";
              data = net.cidr.host 1 vlanCfg.cidrv4;
            }
          ]
          # dns for vlans with internet access
          ++
            lib.optional
              (lib.elem name [
                "management"
                "server"
                "lan"
                "external-vpn"
                "guest"
              ])
              {
                name = "domain-name-servers";
                data = net.cidr.host 1 vlanCfg.cidrv4;
              };

          reservations = lib.concatLists (
            lib.forEach (builtins.attrValues vlanCfg.hosts) (
              hostCfg:
              lib.optional (hostCfg.mac != null) {
                hw-address = hostCfg.mac;
                ip-address = hostCfg.ipv4;
              }
            )
          );
        }
      );

      # Sent to the kea-ddns-consul service, that will publish these as services in consul
      dhcp-ddns = {
        enable-updates = true;
        server-ip = "127.0.0.1";
        server-port = 53010;
        sender-ip = "0.0.0.0";
        sender-port = 0;
        max-queue-size = 1024;
        ncr-protocol = "UDP";
        ncr-format = "JSON";
      };

      ddns-send-updates = true;
      ddns-override-no-update = true;
      ddns-replace-client-name = "never";
      ddns-qualifying-suffix = "";
      ddns-update-on-renew = false;
    };
  };

  # TODO: is this safe?
  networking.firewall.trustedInterfaces = [ "tun-firezone" ];

  networking.nftables = {
    enable = true;

    firewall = {
      zones = {
        firezone.interfaces = [ "tun-firezone" ];
        samba.ipv4Addresses = [
          (net.cidr.host 2 site.vlans.server.cidrv4)
        ];
        wan.interfaces = [ "wan0" ];
        airvpn.interfaces = [ "wg0" ];
        deluge.ipv4Addresses = [ hosts.zeus-arr.ipv4 ];
        other-sites-lan = {
          ingressExpression = [
            "iifname nebula.mesh ip saddr ${globals.sites.erebus.vlans.lan.cidrv4}"
            "iifname nebula.mesh ip saddr ${globals.sites.delphi.vlans.lan.cidrv4}"
          ];
          egressExpression = [
            "oifname nebula.mesh ip daddr ${globals.sites.erebus.vlans.lan.cidrv4}"
            "oifname nebula.mesh ip daddr ${globals.sites.delphi.vlans.lan.cidrv4}"
          ];
        };
      }
      // lib.concatMapAttrs (vlanName: _: {
        "vlan-${vlanName}".interfaces = [ vlanName ];
      }) site.vlans;

      rules = {
        masquerade-internet = {
          from = [
            "vlan-lan"
            "vlan-server"
            "vlan-guest"
            "vlan-iot"
            "vlan-management"
          ];
          to = [ "wan" ];
          # We do our own masquerading without `masquerade random` because
          # nebula has a hard time to establish connections with it enabled
          # masquerade = true;
          late = true; # Only accept after any rejects have been processed
          verdict = "accept";
        };

        # Firezone rules
        forward-incoming-firezone-traffic = {
          from = [ "firezone" ];
          to = [ "vlan-lan" ];
          verdict = "accept";
        };

        forward-outgoing-firezone-traffic = {
          from = [ "vlan-lan" ];
          to = [ "firezone" ];
          verdict = "accept";
        };

        # Allow dns from all devices that have internet access,
        # yes, we leak some DNS data on guest networks, but the
        # traffic is still very blocked
        allow-dns = {
          from = [
            "vlan-lan"
            "vlan-server"
            "vlan-guest"
            "vlan-iot"
            "vlan-management"
          ];
          to = [ "local" ];
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };

        # Allow access to the reverse proxy from lan devices
        allow-reverse-proxy = {
          from = [
            "vlan-lan"
            "vlan-server"
            "vlan-management"
            "vlan-external-vpn"
          ];
          to = [ "local" ];
          allowedTCPPorts = [
            80
            443
            8080 # unifi inform
            1883 # mqtt
          ];
        };

        # External VPN vlan
        allow-external-vpn-dns = {
          from = [ "vlan-external-vpn" ];
          to = [ "local" ];
          allowedTCPPorts = [ 5301 ];
          allowedUDPPorts = [ 5301 ];
        };

        allow-external-vpn-to-airvpn = {
          from = [ "vlan-external-vpn" ];
          to = [ "airvpn" ];
          # masquerade = true;
          late = true;
          verdict = "accept";
        };

        disallow-wan-ssh = {
          from = [ "wan" ];
          to = [ "local" ];
          early = true;
          extraLines = [
            "tcp dport 22 drop"
          ];
        };

        allow-samba = {
          from = [
            "vlan-lan"
            "firezone"
          ];
          to = [ "samba" ];
          allowedTCPPorts = [ 445 ]; # Todo: do we need more ports for samba?
        };

        allow-management-to-all = {
          from = [ "vlan-management" ];
          to = [
            "vlan-lan"
            "vlan-server"
            "vlan-guest"
            "vlan-iot"
            "vlan-external-vpn"
          ];
          verdict = "accept";
        };

        allow-server-communication = {
          from = [
            "vlan-server"
            "vlan-external-vpn"
          ];
          to = [
            "vlan-server"
            "vlan-external-vpn"
            "vlan-lan"
          ];
          verdict = "accept";
        };

        allow-forward-to-deluge = {
          from = [ "airvpn" ];
          to = [ "deluge" ];
          allowedTCPPorts = [ site.airvpn.port ];
          allowedUDPPorts = [ site.airvpn.port ];
        };

        allow-site-to-site-lan = {
          from = [ "vlan-lan" ];
          to = [ "other-sites-lan" ];
          verdict = "accept";
        };
      };
    };

    chains = {
      prerouting = {
        external-vpn-dns = {
          after = [ "hook" ];
          rules = [
            "iifname external-vpn udp dport 53 redirect to :5301"
            "iifname external-vpn tcp dport 53 redirect to :5301"
          ];
        };

        airvpn-forward = {
          after = [ "hook" ];
          rules = [
            "iifname wg0 tcp dport ${airvpn-port} dnat ip to ${hosts.zeus-arr.ipv4}:${airvpn-port}"
            "iifname wg0 udp dport ${airvpn-port} dnat ip to ${hosts.zeus-arr.ipv4}:${airvpn-port}"
          ];
        };
      };

      output = {
        allow-all = {
          after = [ "hook" ];
          rules = [ "type filter hook output priority 0; policy accept;" ];
        };
      };

      postrouting =
        let
          mkMasqueradeRule = name: sourceZones: targetZone: {
            ${name} = {
              after = [ "hook" ];
              late = true;
              rules = lib.forEach sourceZones (
                zone:
                lib.concatStringsSep " " [
                  (lib.head config.networking.nftables.firewall.zones.${zone}.ingressExpression)
                  (lib.head config.networking.nftables.firewall.zones.${targetZone}.egressExpression)
                  "masquerade"
                ]
              );
            };
          };
        in
        lib.mkMerge [
          (mkMasqueradeRule "masquerade-internet" [
            "vlan-lan"
            "vlan-server"
            "vlan-guest"
            "vlan-iot"
            "vlan-management"
          ] "wan")

          (mkMasqueradeRule "masquerade-firezone" [ "firezone" ] "vlan-lan")
          (mkMasqueradeRule "masquerade-airvpn" [ "vlan-external-vpn" ] "airvpn")
        ];
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    reflector = true;
    allowInterfaces = [
      "lan"
      "server"
    ];
  };

  # TODO: yeet
  services.tailscale = {
    enable = true;
    interfaceName = "userspace-networking";
    useRoutingFeatures = "server";
  };
}
