{
  inputs,
  config,
  pkgs,
  lib,
  globals,
  ...
}:
let
  nebulaIp = globals.nebula.mesh.hosts.athena.ipv4;
  site = globals.sites.olympus;
in
{
  # Firewall/router

  imports = [
    ./router
    ./hardware-config.nix
    ./disk-config.nix
    ./traefik.nix
    ../../../config
    ../../../config/optional/zfs.nix
    ../../../config/optional/hardware.nix
  ];

  networking.hostId = "8425e349";

  environment.systemPackages = with pkgs; [
    tcpdump
    mtr
    iperf3
    ethtool
    conntrack-tools
    librespeed-cli
    traceroute
    pciutils
    sysstat
    iftop
    iotop
    cifs-utils
  ];

  age.secrets."consul-acl.json" = {
    rekeyFile = inputs.self.outPath + "/secrets/consul/server.acl.json.age";
    owner = "consul";
  };

  services.consul = {
    enable = true;
    extraConfig = {
      server = true;
      bind_addr = nebulaIp;
      client_addr = nebulaIp;
      retry_join = with globals.nebula.mesh.hosts; [
        demeter.ipv4
        icarus.ipv4
      ];
      bootstrap_expect = 5;
      services = [
        {
          id = "freenas02";
          name = "freenas02";
          port = 443;
          address = lib.net.cidr.host 2 globals.sites.olympus.vlans.server.cidrv4;
        }
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

  globals.nebula.mesh.hosts.athena = {
    id = 4;

    groups = [
      "consul-server"
      "reverse-proxy"
    ];

    routeSubnets = [
      site.vlans.lan.cidrv4
      site.vlans.management.cidrv4
    ];

    config.settings = {
      # TODO: DRY, generate this.
      tun.unsafe_routes = [
        {
          route = globals.sites.erebus.vlans.lan.cidrv4;
          via = globals.nebula.mesh.hosts.charon.ipv4;
        }
        {
          route = globals.sites.delphi.vlans.lan.cidrv4;
          via = globals.nebula.mesh.hosts.pythia.ipv4;
        }
      ];
    };

    firewall.inbound = lib.nebula-firewall.consul-server ++ [
      {
        port = "any";
        proto = "any";
        cidr = globals.sites.erebus.vlans.lan.cidrv4;
        local_cidr = site.vlans.lan.cidrv4;
      }
      {
        port = "any";
        proto = "any";
        cidr = globals.sites.delphi.vlans.lan.cidrv4;
        local_cidr = site.vlans.lan.cidrv4;
      }
      # Allow admins to access management network
      {
        port = "any";
        proto = "any";
        group = "network-admin";
        local_cidr = site.vlans.management.cidrv4;
      }
    ];
  };

  meta.vector.enable = true;
  meta.telegraf = {
    enable = true;
    # monitor connectivity to external and internal services + internet connectivity
    avilableMonitoringNetworks = [
      "external"
      "internal"
      "internet"
    ];
  };

  # Dynamic dns
  age.secrets = {
    cloudflare-dns-api-token.rekeyFile = ./secrets/cloudflare-dns-api-token.age;
  };

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.age.secrets.cloudflare-dns-api-token.path;
    domains = [ "olympus.site.${globals.domains.main}" ];
  };

  system.stateVersion = "24.11";
}
