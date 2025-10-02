{
  inputs,
  globals,
  config,
  lib,
  ...
}:
let
  host = config.node.name;
in
{
  age.secrets."consul-acl.json" = {
    rekeyFile = inputs.self.outPath + "/secrets/consul/agent.acl.json.age";
    owner = "consul";
  };

  services.consul = {
    enable = true;
    extraConfig = {
      server = false;
      bind_addr = globals.nebula.mesh.hosts.${host}.ipv4;
      retry_join = [
        # TODO: dynamically get this from nodes
        globals.nebula.mesh.hosts.icarus.ipv4
        globals.nebula.mesh.hosts.athena.ipv4
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

  globals.nebula.mesh.hosts.${host} = {
    groups = [ "consul-client" ];
    firewall.inbound = lib.nebula-firewall.consul-client;
  };
}
