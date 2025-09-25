{
  inputs,
  globals,
  config,
  lib,
  ...
}:
let
  nebulaIp = globals.nebula.mesh.hosts.orpheus.ipv4;
in
{

  # Edge host at B22

  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
    ./net.nix
    ./samba
    ./snapserver
    ./firezone.nix
    ./ai.nix
    ../../../config
    ../../../config/optional/zfs.nix
    ../../../config/optional/hardware.nix
  ];

  networking.hostId = "fa959c4a";

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
      services = [
        {
          id = "snapcast";
          name = "snapcast";
          port = 1780;
          tags = [
            "traefik.enable=true"
            "traefik.http.routers.snapcast.rule=Host(`snapcast.local.${globals.domains.main}`)"
            "traefik.http.routers.snapcast.entrypoints=websecure"
          ];
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

  meta.vector.enable = true;
  meta.prometheus.enable = true;

  globals.nebula.mesh.hosts.orpheus = {
    id = 2;

    firewall.inbound = lib.nebula-firewall.consul-server;
    groups = [ "consul-server" ];
  };

  # TODO: Add zrepl

  system.stateVersion = "24.11";
}
