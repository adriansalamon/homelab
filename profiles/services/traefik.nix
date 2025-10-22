{
  config,
  nodes,
  lib,
  globals,
  ...
}:
{

  age.secrets = lib.mkIf (config.node.name != "athena") (
    with nodes.athena.config.age;
    {
      # use the same tokens as athena
      "cloudflare-dns-api-token.env".rekeyFile = secrets."cloudflare-dns-api-token.env".rekeyFile;
      "traefik-token.env".rekeyFile = secrets."traefik-token.env".rekeyFile;
    }
  );

  globals.nebula.mesh.hosts."${config.node.name}".groups = [
    "reverse-proxy"
  ];

  services.traefik = {
    enable = true;

    environmentFiles = [
      config.age.secrets."cloudflare-dns-api-token.env".path
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
          asDefault = true;

          http.tls = {
            certResolver = "default";
            domains = [
              {
                main = globals.domains.main;
                sans = [ "*.${globals.domains.main}" ];
              }
              {
                main = "local.${globals.domains.main}";
                sans = [ "*.local.${globals.domains.main}" ];
              }
            ];
          };
        };

        unifi-inform.address = ":8080";
        mqtt.address = ":1883";
        forgejo-ssh.address = ":2222";
      };

      providers.consulCatalog = {
        endpoint = {
          address = "http://consul-api.service.consul:8500";
        };
        exposedByDefault = false;
        defaultRule = "Host(`{{ normalize .Name }}.local.${globals.domains.main}`)";
      };

      log = {
        level = "INFO";
      };

      api = {
        insecure = false;
        dashboard = true;
      };
    };

    dynamicConfigOptions = {
      http = {
        serversTransports.insecure = {
          insecureSkipVerify = true;
        };

        routers.internal = {
          rule = "Host(`traefik-${config.node.site}.local.${globals.domains.main}`)";
          entryPoints = [ "websecure" ];
          service = "api@internal";
          middlewares = [ "authelia@consulcatalog" ];
        };
      };
    };
  };
}
