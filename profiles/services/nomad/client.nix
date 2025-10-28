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
      };

      tls = {
        cert_file = "${nomadSecretDir}/global-client-nomad.pem";
        key_file = config.age.secrets."nomad-client-key.pem".path;
      };
    };

    credentials.secrets = config.age.secrets."nomad-secrets.json".path;

    extraPackages = with pkgs; [
      cni-plugins
      consul
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
