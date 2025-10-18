{
  config,
  inputs,
  lib,
  globals,
  ...
}:
let
  nebula-ipv4 = globals.nebula.mesh.hosts.icarus.ipv4;
in
{
  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
    ../../../config
    ../../../config/optional/zfs.nix
    ../../../config/optional/impermanence.nix
    ./traefik.nix
    ./headscale.nix
    ./net.nix
  ];

  networking.hostId = "3b1ab44f";

  age.secrets."consul-acl.json" = {
    rekeyFile = inputs.self.outPath + "/secrets/consul/server.acl.json.age";
    owner = "consul";
  };

  services.consul = {
    enable = true;

    extraConfig = {
      server = true;
      bind_addr = nebula-ipv4;
      client_addr = nebula-ipv4;
      retry_join = [ globals.nebula.mesh.hosts.demeter.ipv4 ];

      acl = {
        enabled = true;
        default_policy = "deny";
      };
    };

    extraConfigFiles = [
      config.age.secrets."consul-acl.json".path
    ];
  };

  globals.nebula.mesh.hosts.icarus = {
    id = 1;
    lighthouse = true;

    groups = [
      "consul-server"
      "reverse-proxy"
    ];
    firewall.inbound = lib.nebula-firewall.consul-server;
  };

  meta.vector.enable = true;
  meta.telegraf = {
    enable = true;
    # monitor connectivity to external services
    avilableMonitoringNetworks = [ "external" ];
  };

  system.stateVersion = "25.05";
}
