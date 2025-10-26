{
  inputs,
  globals,
  config,
  pkgs,
  ...
}:
let
  host = config.node.name;
  nebulaIp = globals.nebula.mesh.hosts.${host}.ipv4;
in
{
  environment.persistence."/state".directories = [
    {
      directory = "/var/lib/nomad";
      mode = "0700";
      user = "root"; # nomad runs as root :( ?
    }
  ];

  services.nomad = {
    enable = true;
    package = pkgs.nomad;
    dropPrivileges = false;

    settings = {
      data_dir = "/var/lib/nomad";
      bind_addr = nebulaIp;

      # This is implicitly set up, but is here for clarity
      consul = {
        address = "127.0.0.1:8500";
      };

      # Enable TLS for mutual authentication between nodes
      tls = {
        http = true;
        rpc = true;
        ca_file = inputs.self.outPath + "/secrets/nomad/nomad-agent-ca.pem";
        verify_server_hostname = true;
        verify_https_client = false;
      };

      acl = {
        enabled = true;
      };
    };
  };

  globals.nebula.mesh.hosts.${host} = {
    firewall.inbound = [
      {
        port = "4646";
        proto = "tcp";
        group = "nomad-server";
      }
      {
        port = "4646";
        proto = "tcp";
        group = "nomad-client";
      }
    ];
  };
}
