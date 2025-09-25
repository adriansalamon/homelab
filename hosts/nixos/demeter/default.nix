{
  inputs,
  config,
  modulesPath,
  lib,
  globals,
  ...
}:
{
  # Backup NAS/storage server
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk-config.nix
    ./hw.nix
    ./monitoring.nix
    ../../../config
    ../../../config/optional/zfs.nix
    ../../../config/optional/impermanence.nix
    ../../../config/optional/hardware.nix
  ];

  networking.hostId = "40f61b93";
  networking.nftables.enable = true;

  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network = {
    networks."10-physical" = {
      matchConfig.Name = "enp2s0";
      networkConfig = {
        VLAN = "server";
        DHCP = "no";
      };
    };

    networks."10-disable-physical" = {
      matchConfig.Name = "enp4s0";
      networkConfig = {
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

    networks."20-server" = {
      matchConfig.Name = "server";
      networkConfig = {
        Bridge = "serverBr";
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

    networks."40-microvms" = {
      matchConfig.Name = "vm-*";
      networkConfig = {
        Bridge = "serverBr";
      };
    };
  };

  networking.nftables.firewall.zones.untrusted.interfaces = [ "serverBr" ];

  services.microbin = {
    enable = true;
  };

  consul.services.microbin = {
    port = 8080;
    tags = [
      "traefik.enable=true"
      "traefik.external=true"
      "traefik.http.routers.microbin.rule=Host(`microbin.${globals.domains.main}`)"
      "traefik.http.routers.microbin.entrypoints=websecure"
      "traefik.http.routers.microbin.middlewares=authelia"
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
      bind_addr = globals.nebula.mesh.hosts.demeter.ipv4;
      client_addr = globals.nebula.mesh.hosts.demeter.ipv4;
      retry_join = [ globals.nebula.mesh.hosts.icarus.ipv4 ];

      acl = {
        enabled = true;
        default_policy = "deny";
      };
    };

    extraConfigFiles = [
      config.age.secrets."consul-acl.json".path
    ];
  };

  globals.nebula.mesh.hosts.demeter = {
    id = 3;

    groups = [ "consul-server" ];

    config.settings = {
      config.settings = {
        preferred_ranges = [
          "185.81.109.88"
        ];
      };
    };

    firewall.inbound = lib.nebula-firewall.consul-server ++ [
      {
        port = "8080"; # microbin
        proto = "tcp";
        group = "reverse-proxy";
      }
    ];
  };

  meta.vector.enable = true;
  meta.prometheus.enable = true;

  system.stateVersion = "24.11";
}
