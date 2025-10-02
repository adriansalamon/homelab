{
  config,
  lib,
  globals,
  ...
}:
let
  inherit (lib)
    flip
    concatMapAttrs
    mapAttrsToList
    net
    ;

  site = globals.sites.delphi;
in
{
  boot.kernel.sysctl = {
    # we are a router, yay!
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.src_valid_mark" = 1;
    "net.ipv6.conf.all.disable_ipv6" = 1;
  };

  networking.hostId = "2a48ff8c";

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="c8:ff:bf:04:fe:d9", NAME="wan0"
    ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="c8:ff:bf:04:fe:d8", NAME="lan0"
  '';

  networking = {
    useNetworkd = true;
    resolvconf.enable = false;
  };

  systemd.network.enable = true;
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

      address = lib.optional (site.default.cidrv4 != null) (lib.net.cidr.hostCidr 1 site.default.cidrv4);
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

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config = {
        interfaces = flip mapAttrsToList site.vlans (name: _: name) ++ [ "lan0" ];
      };
      subnet4 =
        flip mapAttrsToList site.vlans (
          name: vlanCfg: {
            inherit (vlanCfg) id;
            interface = name;
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
                  "lan"
                  "server"
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
        )
        ++ [
          {
            id = 1;
            interface = "lan0";
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
          }
        ];

      # Sent to the kea-ddns-consul service, that will publish these as services in consul
      dhcp-ddns = {
        enable-updates = true;
        server-ip = "127.0.0.1";
        server-port = 53010;
        sender-ip = "";
        sender-port = 0;
        max-queue-size = 1024;
        ncr-protocol = "UDP";
        ncr-format = "JSON";
      };

      ddns-send-updates = true;
      ddns-override-no-update = true;
      ddns-override-client-update = true;
      ddns-replace-client-name = "never";
      ddns-qualifying-suffix = "";
      ddns-update-on-renew = true;
    };
  };

  networking.nftables = {
    enable = true;

    firewall = {
      zones = {
        wan.interfaces = [ "wan0" ];
        lan.interfaces = [ "lan0" ];
        other-sites-lan = {
          ingressExpression = [
            "iifname nebula.mesh ip saddr ${globals.sites.olympus.vlans.lan.cidrv4}"
            "iifname nebula.mesh ip saddr ${globals.sites.erebus.vlans.lan.cidrv4}"
          ];
          egressExpression = [
            "oifname nebula.mesh ip daddr ${globals.sites.olympus.vlans.lan.cidrv4}"
            "oifname nebula.mesh ip daddr ${globals.sites.erebus.vlans.lan.cidrv4}"
          ];
        };
        firezone.interfaces = [ "tun-firezone" ];
      }
      // lib.concatMapAttrs (vlanName: _: {
        "vlan-${vlanName}".interfaces = [ vlanName ];
      }) site.vlans;

      rules = {
        masquerade-internet = {
          from = [
            "lan"
            "vlan-lan"
            "vlan-server"
            "vlan-guest"
            "vlan-iot"
          ];
          to = [ "wan" ];
          # We do our own masquerading without `masquerade random` because
          # nebula has a hard time to establish connections with it enabled
          # masquerade = true;
          late = true; # Only accept after any rejects have been processed
          verdict = "accept";
        };

        # Allow dns from all devices that have internet access,
        # yes, we leak some DNS data on guest networks, but the
        # traffic is still very blocked
        allow-dns = {
          from = [
            "lan"
            "vlan-lan"
            "vlan-server"
            "vlan-guest"
            "vlan-iot"
          ];
          to = [ "local" ];
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };

        # Allow access to the reverse proxy from lan devices
        allow-reverse-proxy = {
          from = [
            "lan"
            "vlan-lan"
            "vlan-server"
          ];
          to = [ "local" ];
          allowedTCPPorts = [
            80
            443
            8080 # unifi inform
            1883 # mqtt
          ];
        };

        # disallow-wan-ssh = {
        #   from = [ "wan" ];
        #   to = [ "local" ];
        #   early = true;
        #   extraLines = [
        #     "tcp dport 22 drop"
        #   ];
        # };

        allow-server-communication = {
          from = [ "vlan-server" ];
          to = [ "vlan-lan" ];
          verdict = "accept";
        };

        allow-site-to-site-lan = {
          from = [ "vlan-lan" ];
          to = [ "other-sites-lan" ];
          verdict = "accept";
        };

        # firezone
        masquerade-firezone = {
          from = [ "firezone" ];
          to = [ "vlan-lan" ];
          # masquerade = true;
          late = true; # Only accept after any rejects have been processed
          verdict = "accept";
        };

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
      };
    };

    chains = {
      output = {
        allow-all = {
          after = [ "hook" ];
          rules = [ "type filter hook output priority 0; policy accept;" ];
        };
      };

      postrouting =
        let
          inherit (config.helpers.nftables) mkMasqueradeRule;
        in
        lib.mkMerge [
          (mkMasqueradeRule "masquerade-internet"
            [
              "vlan-lan"
              "vlan-server"
              "vlan-guest"
              "vlan-iot"
            ]
            [ "wan" ]
          )
          (mkMasqueradeRule "masquerade-firezone" [ "firezone" ] [ "vlan-lan" ])
        ];
    };
  };

  globals.nebula.mesh.hosts.pythia = {
    id = 7;

    routeSubnets = [
      site.vlans.lan.cidrv4
    ];

    config.settings = {
      tun.unsafe_routes = [
        {
          route = globals.sites.olympus.vlans.lan.cidrv4;
          via = globals.nebula.mesh.hosts.athena.ipv4;
        }
        {
          route = globals.sites.erebus.vlans.lan.cidrv4;
          via = globals.nebula.mesh.hosts.charon.ipv4;
        }
      ];
    };

    groups = [
      "reverse-proxy"
    ];

    firewall.inbound = [
      {
        port = "any";
        proto = "any";
        cidr = globals.sites.olympus.vlans.lan.cidrv4;
        local_cidr = site.vlans.lan.cidrv4;
      }
      {
        port = "any";
        proto = "any";
        cidr = globals.sites.erebus.vlans.lan.cidrv4;
        local_cidr = site.vlans.lan.cidrv4;
      }
    ];
  };
}
