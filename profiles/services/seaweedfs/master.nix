{
  config,
  globals,
  lib,
  ...
}:
let
  host = config.node.name;
  nebulaIp = globals.nebula.mesh.hosts.${host}.ipv4;

  peers = builtins.filter (master: master != host) [
    "athena"
    "charon"
    "pythia"
  ];

in
{
  environment.persistence."/persist".directories = [
    {
      directory = config.services.seaweedfs.master.dataDir;
      mode = "0700";
      user = "seaweedfs";
    }
  ];

  environment.systemPackages = [
    config.services.seaweedfs.package
  ];

  services.seaweedfs = {
    enable = true;

    master = {
      enable = true;
      ip = nebulaIp;

      peers = map (peer: {
        ip = globals.nebula.mesh.hosts.${peer}.ipv4;
        inherit (config.services.seaweedfs.master) port;
      }) peers;
    };
  };

  globals.nebula.mesh.hosts.${host} = {
    groups = [ "weed-master" ];
    firewall.inbound = lib.flatten (
      map
        (group: [
          {
            inherit (config.services.seaweedfs.master) port;
            proto = "tcp";
            inherit group;
          } # gRPC port (defaults to port + 10000)
          {
            port = config.services.seaweedfs.master.port + 10000;
            proto = "tcp";
            inherit group;
          }
        ])
        [
          "weed-master"
          "weed-volume"
          "weed-filer"
        ]
    );
  };

  consul.services = {
    seaweedfs-http-master = {
      name = "seaweedfs-master";
      inherit (config.services.seaweedfs.master) port;
      tags = [ "http" ];
    };

    seaweedfs-grpc-master = {
      name = "seaweedfs-master";
      port = config.services.seaweedfs.master.port + 10000;
      tags = [ "grpc" ];
    };
  };
}
