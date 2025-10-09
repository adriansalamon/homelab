{
  config,
  inputs,
  pkgs,
  globals,
  nodes,
  lib,
  ...
}:
let
  nebulaIp = globals.nebula.mesh.hosts.zeus.ipv4;
in
{
  # Main VM host

  imports = [
    inputs.microvm.nixosModules.host
    ./hardware-config.nix
    ./disk-config.nix
    ./jellyfin.nix
    ./immich.nix
    ./services
    ../../../config
    ../../../config/optional/zfs.nix
    ../../../config/optional/impermanence.nix
    ../../../config/optional/hardware.nix
    ../../../config/optional/storage-users.nix
  ];

  networking.hostId = "49e32584";

  environment.systemPackages = with pkgs; [
    dnsutils
    curl
    gitMinimal
    zfs
    vim
    htop
    ipmitool
  ];

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

  globals.nebula.mesh.hosts.zeus = {
    id = 5;
    groups = [
      "consul-server"
      "nfs-client"
    ];

    firewall.inbound = lib.nebula-firewall.consul-server ++ [
      {
        port = "8500";
        proto = "tcp";
        group = "reverse-proxy";
      }
    ];
  };

  age.secrets."consul-acl.json" = {
    rekeyFile = inputs.self.outPath + "/secrets/consul/server.acl.json.age";
    owner = "consul";
  };

  services.consul = {
    enable = true;
    webUi = true;
    extraConfig = {
      server = true;
      ui = true;
      bind_addr = nebulaIp;
      client_addr = nebulaIp;
      retry_join = with globals.nebula.mesh.hosts; [
        demeter.ipv4
        icarus.ipv4
      ];

      acl = {
        enabled = true;
        default_policy = "deny";
      };
    };

    extraConfigFiles = [
      config.age.secrets."consul-acl.json".path
    ];
  };

  consul.services = {
    consul-api.port = 8500;
    consul-ui = {
      port = 8500;
      tags = [
        "traefik.enable=true"
        "traefik.http.routers.consul.rule=Host(`consul.local.${globals.domains.main}`)"
        "traefik.http.routers.consul.middlewares=authelia"
      ];
    };
  };

  guests =
    let
      mkGuest = guestName: guestCfg: {
        autostart = true;
        zfs."/state" = {
          pool = "zroot";
          dataset = "local/guests/${guestName}";
        };
        zfs."/persist" = {
          pool = "zroot";
          dataset = "safe/guests/${guestName}";
        };
        modules = [
          ../../../config
          ../../../config/optional/impermanence.nix
          ./guests/common.nix
          ./guests/${guestName}.nix
          {
            node.secretsDir = ./secrets/${guestName};
            networking.nftables.firewall = {
              zones.untrusted.interfaces = lib.mapAttrsToList (
                ifaceName: _: ifaceName
              ) config.guests.${guestName}.microvm.interfaces;
            };
          }
          guestCfg
        ];
      };

      mkMicrovm =
        guestName:
        {
          bridge ? "serverBr",
          id,
        }:
        {
          ${guestName} = mkGuest guestName { node.id = id; } // {
            microvm.system = "x86_64-linux";
            microvm.interfaces.eth0 = { inherit bridge; };

            extraSpecialArgs = {
              inherit (inputs.self.pkgs.x86_64-linux) lib;
              inherit inputs globals nodes;
            };
          };
        };
    in
    lib.mkMerge [
      (mkMicrovm "unifi" { id = 2049; })
      (mkMicrovm "arr" {
        bridge = "vpnBr";
        id = 2050;
      })
      (mkMicrovm "home-assistant" { id = 2051; })
      (mkMicrovm "auth" { id = 2052; })
      (mkMicrovm "paperless" { id = 2053; })
      (mkMicrovm "loki" { id = 2054; })
      (mkMicrovm "prometheus" { id = 2055; })
      (mkMicrovm "grafana" { id = 2056; })
    ];

  systemd.tmpfiles.rules =
    let
      guestNames = builtins.attrNames config.guests;
      createRulesForGuest = guestName: [
        "d /guests/${guestName}/persist/var/lib/nixos 0755 root root -"
        "d /guests/${guestName}/state/var/log 0755 root root -"
      ];
    in
    lib.flatten (map createRulesForGuest guestNames);

  meta.vector.enable = true;
  meta.prometheus.enable = true;

  system.stateVersion = "24.11";
}
