{ config, globals, ... }:
let
  host = config.node.name;
  nebulaIp = globals.nebula.mesh.hosts.${host}.ipv4;

  masters = [
    "athena"
    "charon"
    "pythia"
  ];
in
{

  # Note: this profile assumes that the /data/seaweedfs directory exists

  environment.systemPackages = [
    config.services.seaweedfs.package
  ];

  systemd.tmpfiles.rules = [
    "d /data/seaweedfs 0700 seaweedfs seaweedfs"
  ];

  services.seaweedfs = {
    enable = true;

    volume = {
      enable = true;
      ip = nebulaIp;

      masters = map (peer: {
        ip = globals.nebula.mesh.hosts.${peer}.ipv4;
        port = config.services.seaweedfs.master.port;
      }) masters;

      dataCenter = config.node.site;
      rack = config.node.name;

      dataDirs = [ "/data/seaweedfs" ];
      maxVolumes = 0;
      minFreeSpacePercent = 10;
    };
  };

  globals.nebula.mesh.hosts.${host}.firewall.inbound = [
    {
      port = config.services.seaweedfs.volume.port;
      proto = "tcp";
      host = "any";
    }
    {
      port = config.services.seaweedfs.volume.port + 10000;
      proto = "tcp";
      host = "any";
    }
  ];

  consul.services = {
    seaweedfs-http-volume = {
      name = "seaweedfs-volume";
      port = config.services.seaweedfs.volume.port;
      tags = [ "http" ];
    };

    seaweedfs-grpc-volume = {
      name = "seaweedfs-volume";
      port = config.services.seaweedfs.volume.port + 10000;
      tags = [ "grpc" ];
    };
  };
}
