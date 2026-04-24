{
  inputs,
  globals,
  config,
  pkgs,
  lib,
  ...
}:
let

  inherit (lib)
    mkIf
    mkEnableOption
    ;

  host = config.node.name;
  nebulaIp = globals.nebula.mesh.hosts.${host}.ipv4;

  cfg = config.services.nomad-common;
in
{
  options.services.nomad-common = {
    enable = mkEnableOption "Nomad common profile module";
  };

  config = mkIf cfg.enable {
    environment.persistence."/state".directories = [
      {
        directory = "/var/lib/nomad";
        mode = "0700";
        user = "root"; # nomad runs as root :( ?
      }
    ];

    environment.etc."nomad/nomad-agent-ca.pem" = {
      source = inputs.self.outPath + "/secrets/nomad/nomad-agent-ca.pem";
      mode = "0444";
    };

    services.nomad = {
      enable = true;
      package = pkgs.nomad_1_11;
      dropPrivileges = false;

      settings = {
        data_dir = "/var/lib/nomad";
        bind_addr = nebulaIp;

        consul = {
          address = "127.0.0.1:8500";
        };

        vault = {
          enabled = true;
        };

        # Enable TLS for mutual authentication between nodes
        tls = {
          http = true;
          rpc = true;
          ca_file = "/etc/nomad/nomad-agent-ca.pem";
          verify_server_hostname = true;
          verify_https_client = false;
        };

        acl = {
          enabled = true;
        };

        telemetry = {
          publish_allocation_metrics = true;
          publish_node_metrics = true;
          prometheus_metrics = true;
          disable_hostname = true;
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
        {
          port = "4646";
          proto = "tcp";
          group = "metrics-collector";
        }
      ];
    };
  };
}
