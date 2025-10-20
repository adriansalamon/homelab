{
  modulesPath,
  profiles,
  ...
}:
{
  # Backup NAS/storage server
  imports = with profiles; [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disk-config.nix
    ./hw.nix
    common
    zfs
    impermanence
    hardware
    services.consul-server
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

  globals.nebula.mesh.hosts.demeter = {
    id = 3;
  };

  meta.vector.enable = true;
  meta.telegraf.enable = true;

  system.stateVersion = "24.11";
}
