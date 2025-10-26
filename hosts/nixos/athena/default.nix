{
  inputs,
  config,
  pkgs,
  globals,
  profiles,
  lib,
  ...
}:
let
  site = globals.sites.olympus;
in
{
  # Firewall/router

  imports = with profiles; [
    ./router
    ./hardware-config.nix
    ./disk-config.nix
    common
    zfs
    hardware
    impermanence
    services.consul-server
    services.nomad.server
    services.traefik
    services.valkey-server
    router.nebula
    router.monitoring
  ];

  systemd.enableEmergencyMode = false;

  networking.hostId = "8425e349";
  node.site = "olympus";

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

  globals.nebula.mesh.hosts.athena = {
    id = 4;

    routeSubnets = [
      site.vlans.lan.cidrv4
      site.vlans.management.cidrv4
    ];

    firewall.inbound = [
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
    # monitor connectivity to external and internal services
    avilableMonitoringNetworks = [
      "external"
      "internal"
    ];
  };

  age.secrets = {
    # Dynamic DNS
    cloudflare-dns-api-token.rekeyFile = ./secrets/cloudflare-dns-api-token.age;

    # Wrap with env var for traefik
    "cloudflare-dns-api-token.env" = {
      generator.dependencies = [ config.age.secrets.cloudflare-dns-api-token ];
      generator.script = lib.helpers.generateWithEnv "CF_DNS_API_TOKEN";
    };

    traefik-token.rekeyFile = inputs.self.outPath + "/secrets/consul/traefik.age";
    "traefik-token.env" = {
      generator.dependencies = [ config.age.secrets.traefik-token ];
      generator.script = lib.helpers.generateWithEnv "TRAEFIK_PROVIDERS_CONSULCATALOG_ENDPOINT_TOKEN";
    };
  };

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.age.secrets.cloudflare-dns-api-token.path;
    domains = [ "olympus.site.${globals.domains.main}" ];
  };

  system.stateVersion = "24.11";
}
