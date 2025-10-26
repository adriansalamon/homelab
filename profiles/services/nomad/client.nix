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

  age.secrets."server-client-key.pem" = {
    rekeyFile = "${nomadSecretDir}/global-client-nomad-key.pem.age";
  };

  # { "consul": { "token": "xxxxx" } }
  age.secrets."nomad-secrets.json" = {
    rekeyFile = "${nomadSecretDir}/client.json.age";
  };

  services.nomad = {
    enableDocker = true;

    settings = {
      client = {
        enabled = true;
        network_interface = "nebula.mesh";
        cni_path = "${pkgs.cni-plugins}/bin";
      };

      tls = {
        cert_file = "${nomadSecretDir}/global-client-nomad.pem";
        key_file = config.age.secrets."server-client-key.pem".path;
      };
    };

    credentials.secrets = config.age.secrets."nomad-secrets.json".path;

    extraPackages = with pkgs; [
      cni-plugins
    ];
  };

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
