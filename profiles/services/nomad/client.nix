{
  inputs,
  config,
  pkgs,
  ...
}:
let
  host = config.node.name;
  nomadSecretDir = inputs.self.outPath + "/secrets/nomad/";
in
{
  imports = [ ./common.nix ];

  age.secrets."nomad-client-key.pem" = {
    rekeyFile = "${nomadSecretDir}/global-client-nomad-key.pem.age";
  };

  # { "consul": { "token": "xxxxx" } }
  age.secrets."nomad-secrets.json" = {
    rekeyFile = "${nomadSecretDir}/client.json.age";
  };

  boot.initrd.kernelModules = [
    "bridge"
    "br_netfilter"
  ];

  services.nomad = {
    enableDocker = true;

    settings = {
      client = {
        enabled = true;
        network_interface = "nebula.mesh";
        cni_path = "${pkgs.cni-plugins}/bin:${pkgs.cni-plugin-flannel}/bin";
        cni_config_dir = "/etc/cni/net.d";

        host_volume."docker-socket" = {
          path = "/var/run/docker.sock";
          read_only = true;
        };
      };

      tls = {
        cert_file = "${nomadSecretDir}/global-client-nomad.pem";
        key_file = config.age.secrets."nomad-client-key.pem".path;
      };

      telemetry = {
        publish_allocation_metrics = true;
        publish_node_metrics = true;
        prometheus_metrics = true;
      };

      plugin.docker.config.extra_labels = [
        "job_name"
        "task_group_name"
        "task_name"
        "namespace"
        "node_name"
      ];
    };

    credentials.secrets = config.age.secrets."nomad-secrets.json".path;

    extraPackages = with pkgs; [
      cni-plugins
      consul
    ];
  };

  consul.services.nomad-client = {
    port = 4646;
    tags = [
      "prometheus.scrape=true"
      "prometheus.path=/v1/metrics"
      "prometheus.scheme=https"
      "prometheus.query.format=prometheus"
    ];
  };

  services.flannel = {
    enable = true;
    iface = "nebula.mesh";
    etcd = {
      prefix = "/coreos.com/network";
      endpoints = [ "http://etcd-client.service.consul:2379" ];
    };
    # is auto-provisioned into etcd
    network = "10.65.0.0/16";
    subnetLen = 24;
    backend = {
      Type = "vxlan";
    };
  };

  environment.etc."cni/net.d/10-flannel.conflist".text = ''
    {
      "cniVersion": "0.4.0",
      "name": "flannel",
      "plugins": [
        {
          "type": "flannel",
          "delegate": {
            "isDefaultGateway": true,
            "hairpinMode": true
          }
        },
        {
          "type": "portmap",
          "capabilities": { "portMappings": true }
        }
      ]
    }
  '';

  globals.nebula.mesh.hosts.${host} = {
    groups = [ "nomad-client" ];

    firewall.inbound = [
      # vxvlan
      {
        port = 8472;
        proto = "udp";
        group = "nomad-client";
      }
      {
        port = 4646;
        proto = "tcp";
        group = "any";
      }
      {
        port = "20000-32000";
        proto = "tcp";
        group = "any";
      }
      {
        port = "20000-32000";
        proto = "udp";
        group = "any";
      }
    ];
  };
}
