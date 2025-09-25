{
  inputs,
  config,
  lib,
  globals,
  ...
}:
{

  age.secrets = {
    "cloudflare-dns-api-token.env" = {
      generator.dependencies = [ config.age.secrets.cloudflare-dns-api-token ];
      generator.script = lib.helpers.generateWithEnv "CF_DNS_API_TOKEN";
    };

    traefik-token.rekeyFile = inputs.self.outPath + "/secrets/consul/traefik.age";
    "traefik-token.env" = {
      generator.dependencies = [ config.age.secrets.traefik-token ];
      generator.script = lib.helpers.generateWithEnv "TRAEFIK_PROVIDERS_CONSULCATALOG_ENDPOINT_TOKEN";
    };
  };

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
      };
    };
  };

  consul.services.traefik = {
    port = 8080;
    address = lib.net.cidr.host 1 globals.sites.olympus.vlans.lan.cidrv4;
    tags = [
      "traefik.enable=true"
      "traefik.http.routers.traefik.rule=Host(`traefik.local.${globals.domains.main}`)"
      "traefik.http.routers.traefik.entrypoints=websecure"
      "traefik.http.routers.traefik.service=api@internal"
      "traefik.http.routers.traefik.middlewares=authelia"
    ];
  };
}
