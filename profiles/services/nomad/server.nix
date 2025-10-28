{
  inputs,
  config,
  globals,
  ...
}:
let
  host = config.node.name;
  nomadSecretDir = inputs.self.outPath + "/secrets/nomad/";
in
{
  imports = [ ./common.nix ];

  age.secrets."server-nomad-key.pem" = {
    rekeyFile = "${nomadSecretDir}/global-server-nomad-key.pem.age";
  };

  # { "consul": { "token": "xxxxx" }, "server": { "encrypt": "xxxx" } }
  age.secrets."nomad-secrets.json" = {
    rekeyFile = "${nomadSecretDir}/server.json.age";
  };

  services.nomad = {
    enableDocker = false;

    settings = {
      server = {
        enabled = true;
        bootstrap_expect = 3;
      };

      # For services and tasks to get identities from Consul
      consul = {
        service_identity = {
          aud = [ "consul.io" ];
          ttl = "1h";
        };

        task_identity = {
          aud = [ "consul.io" ];
          ttl = "1h";
        };
      };

      tls = {
        cert_file = "${nomadSecretDir}/global-server-nomad.pem";
        key_file = config.age.secrets."server-nomad-key.pem".path;
      };
    };

    credentials.secrets = config.age.secrets."nomad-secrets.json".path;
  };

  consul.services.nomad-ui = {
    port = 4646;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.nomad-ui.rule=Host(`nomad.local.${globals.domains.main}`)"
      "traefik.http.services.nomad-ui.loadbalancer.server.scheme=https"
      "traefik.http.services.nomad-ui.loadbalancer.serversTransport=insecure@file"
    ];
  };

  globals.nebula.mesh.hosts.${host} = {
    groups = [ "nomad-server" ];

    firewall.inbound = [
      {
        port = "4647";
        proto = "tcp";
        group = "nomad-server";
      }
      {
        port = "4647";
        proto = "tcp";
        group = "nomad-client";
      }
      # Nomad gossip (serf)
      {
        port = "4648";
        proto = "tcp";
        group = "nomad-server";
      }
      {
        port = "4648";
        proto = "udp";
        group = "nomad-server";
      }
      # Traefik for the UI
      {
        port = "4646";
        proto = "tcp";
        group = "reverse-proxy";
      }
    ];
  };
}
