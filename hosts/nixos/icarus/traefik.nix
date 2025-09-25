{
  config,
  nodes,
  globals,
  ...
}:
{
  age.secrets = with nodes.athena.config.age; {
    # use the same tokens
    cloudflare-dns-api-token.rekeyFile = secrets.cloudflare-dns-api-token.rekeyFile;
    "traefik-token.env".rekeyFile = secrets."traefik-token.env".rekeyFile;
  };

  services.traefik = {
    enable = true;

    environmentFiles = [
      config.age.secrets.cloudflare-dns-api-token.path
      config.age.secrets."traefik-token.env".path
    ];

    staticConfigOptions = {
      certificatesresolvers.default.acme = {
        email = "adrian@${globals.domains.alt}";
        storage = "${config.services.traefik.dataDir}/acme.json";
        dnschallenge = {
          provider = "cloudflare";
          resolvers = [ "1.1.1.1:53" ];
        };
      };

      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entryPoint = {
            to = "websecure";
            scheme = "https";
            permanent = "true";
          };
        };

        websecure = {
          address = ":443";
          http.tls = {
            certResolver = "default";
            domains = [
              {
                main = "${globals.domains.alt}";
                sans = [ "*.${globals.domains.alt}" ];
              }
              {
                main = "${globals.domains.main}";
                sans = [ "*.${globals.domains.main}" ];
              }
            ];
          };
        };

        unifi-inform.address = ":8080";

        traefik.address = ":9090"; # internal only
      };

      providers.consulCatalog = {
        endpoint = {
          address = "http://${globals.nebula.mesh.hosts.icarus.ipv4}:8500";
        };
        exposedByDefault = false;
        constraints = "Tag(`traefik.external=true`)";
      };

      log = {
        level = "INFO";
      };

      api = {
        insecure = true; # Only exposed internally via internal reverse proxy, so safe
        dashboard = true;
      };
    };

    dynamicConfigOptions = {
      http = {
        serversTransports.insecure = {
          insecureSkipVerify = true;
        };
      };
    };
  };

  consul.services.traefik-external = {
    port = 9090;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.traefik-external.rule=Host(`traefik-external.local.${globals.domains.main}`)"
      "traefik.http.routers.traefik-external.entrypoints=websecure"
      "traefik.http.routers.traefik-external.middlewares=authelia"
    ];
  };

  globals.nebula.mesh.hosts.icarus.firewall.inbound = [
    {
      port = 9090;
      proto = "tcp";
      group = "reverse-proxy";
    }
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
    8080
  ];
}
