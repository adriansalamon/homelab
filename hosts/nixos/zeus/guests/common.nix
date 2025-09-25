{
  inputs,
  config,
  globals,
  lib,
  ...
}:
let
  node = config.node;
in
{
  # All nodes definetely want to be in the nebula mesh.
  globals.nebula.mesh.hosts.${node.name} = {
    inherit (node) id;
    groups = [ "consul-client" ];

    firewall.inbound = lib.nebula-firewall.consul-client;
  };

  # Assumes that every node wants Consul agent. Probably true.
  services.consul = {
    enable = true;
    extraConfig = {
      server = false;
      bind_addr = globals.nebula.mesh.hosts.${node.name}.ipv4;
      retry_join = [ "consul.service.consul" ];

      acl = {
        enabled = true;
        default_policy = "deny";
      };
    };

    extraConfigFiles = [
      config.age.secrets."consul-acl.json".path
    ];
  };

  age.secrets."consul-acl.json" = {
    rekeyFile = inputs.self.outPath + "/secrets/consul/agent.acl.json.age";
    owner = "consul";
  };

  # we all want vector logging :P
  meta.vector.enable = true;

  networking.useNetworkd = true;
  system.stateVersion = "24.11";
}
