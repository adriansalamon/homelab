{
  inputs,
  globals,
  config,
  ...
}:
let

  host = config.node.name;

  consulServers = map (name: globals.nebula.mesh.hosts.${name}.ipv4) globals.consul-servers;
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
      client_addr = "127.0.0.1";
      retry_join = consulServers;

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
    firewall.inbound = [
      {
        port = "8301";
        proto = "tcp";
        group = "consul-server";
      }
      {
        port = "8301";
        proto = "udp";
        group = "consul-server";
      }
      {
        port = "8301";
        proto = "tcp";
        group = "consul-client";
      }
      {
        port = "8301";
        proto = "udp";
        group = "consul-client";
      }
    ];
  };
}
