{
  inputs,
  globals,
  config,
  ...
}:
let

  host = config.node.name;

  consulServers = map (name: globals.nebula.mesh.hosts.${name}.ipv4) (
    builtins.filter (name: name != host) globals.consul-servers
  );

  nebulaIp = globals.nebula.mesh.hosts.${host}.ipv4;
in
{

  # note: this means that the server must use impermanence on /persist
  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/consul";
      mode = "0700";
      user = "consul";
      group = "consul";
    }
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
      retry_join = consulServers;
      bootstrap_expect = builtins.length globals.consul-servers;

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
    groups = [ "consul-server" ];
    firewall.inbound = [
      {
        port = "8300-8302";
        proto = "tcp";
        group = "consul-server";
      }
      {
        port = "8301";
        proto = "udp";
        group = "consul-server";
      }
      {
        port = "8300-8301";
        proto = "tcp";
        group = "consul-client";
      }
      {
        port = "8301";
        proto = "udp";
        group = "consul-client";
      }
      {
        port = "8500";
        proto = "tcp";
        group = "consul-client";
      }
    ];
  };
}
