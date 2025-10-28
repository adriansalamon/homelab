{
  config,
  globals,
  lib,
  ...
}:
let
  nebulaIp = globals.nebula.mesh.hosts.${config.node.name}.ipv4;
in
{
  environment.persistence."/state".directories = lib.singleton {
    directory = "/var/lib/etcd";
    user = "etcd";
    mode = "700";
  };

  services.etcd = {
    enable = true;
    listenClientUrls = [ "http://${nebulaIp}:2379" ];
    listenPeerUrls = [ "http://${nebulaIp}:2380" ];
    initialClusterState = "existing";
    extraConf = {
      "DISCOVERY_SRV" = "service.consul";
      "INITIAL_CLUSTER" = lib.mkForce "";
    };
  };

  globals.nebula.mesh.hosts.${config.node.name}.firewall.inbound = [
    {
      port = "2379";
      proto = "tcp";
      host = "any";
    }
    {
      port = "2380";
      proto = "tcp";
      host = "any";
    }
  ];

  consul.services.etcd-server = {
    port = 2380;
    # we can't do health checks here because etcd relies on srv dns records of itself being up
  };

  consul.services.etcd-client = {
    port = 2379;

    checks = lib.singleton {
      tcp = "${nebulaIp}:2380";
      interval = "30s";
      timeout = "2s";
    };
  };
}
