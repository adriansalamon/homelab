{
  config,
  globals,
  nodes,
  lib,
  ...
}:
let
  nebulaIp = globals.nebula.mesh.hosts.icarus.ipv4;

  inherit (lib)
    flip
    mapAttrs
    concatMapAttrs
    ;
in
{

  age.secrets.firezone-smtp-password = {
    rekeyFile = config.node.secretsDir + "/firezone-smtp-password.age";
  };

  age.secrets.firezone-relay-token = {
    rekeyFile = config.node.secretsDir + "/firezone-relay-token.age";
  };

  age.secrets.firezone-oidc-client-secret = {
    inherit (nodes.zeus-auth.config.age.secrets.firezone-oidc-client-secret) rekeyFile;
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/private/firezone";
      mode = "0700";
    }
  ];

  services.firezone.server = {
    enable = false;
    enableLocalDB = true;

    smtp = {
      from = "firezone@${globals.domains.main}";
      host = "email-smtp.eu-west-1.amazonaws.com";
      port = 587;
      username = builtins.readFile ./secrets/firezone-smtp-username.txt;
      passwordFile = config.age.secrets.firezone-smtp-password.path;
    };

    web = {
      port = 8082;
      address = nebulaIp;
      externalUrl = "https://firezone.${globals.domains.main}/";
    };

    api = {
      port = 8081;
      address = nebulaIp;
      externalUrl = "https://firezone-api.${globals.domains.main}/";
    };

    provision = {
      enable = false;

      accounts.main = {
        name = "Salamon";
        relayGroups.relays.name = "Relays";

        gatewayGroups = flip mapAttrs globals.sites (
          site: _: {
            name = lib.strings.toSentenceCase site;
          }
        );

        actors.admin = {
          type = "account_admin_user";
          name = "Admin";
          email = "adrian@${globals.domains.alt}";
        };

        auth.oidc = {
          name = "Authelia";
          adapter = "openid_connect";
          adapter_config = {
            scope = "openid email profile";
            response_type = "code";
            client_id = "firezone";
            discovery_document_uri = "https://auth.${globals.domains.main}/.well-known/openid-configuration";
            clientSecretFile = config.age.secrets.firezone-oidc-client-secret.path;
          };
        };

        resources = flip concatMapAttrs globals.sites (
          site: siteCfg: {
            "${site}-lan" = {
              type = "cidr";
              name = "${site}-lan";
              address = siteCfg.vlans.lan.cidrv4;
              gatewayGroups = [ site ];
            };
          }
        );

        groups.main = {
          name = "main";
          members = [
            "admin"
          ];
        };

        policies = flip concatMapAttrs globals.sites (
          site: siteCfg: {
            "allow-everyone-to-${site}-lan" = {
              resource = "${site}-lan";
              group = "main";
              description = "Allow everyone to ${site}-lan";
            };
          }
        );
      };
    };
  };

  services.firezone.relay = {
    enable = false;
    name = "icarus";
    apiUrl = "wss://firezone-api.${globals.domains.main}/";
    tokenFile = config.age.secrets.firezone-relay-token.path;
    publicIpv4 = config.node.publicIp;
    publicIpv6 = "2a01:4f9:c013:bec3::1";
    openFirewall = true;
  };

  # systemd.services.firezone-relay = {
  #   after = [ "firezone-server-api.service" ];
  #   wants = [ "firezone-server-api.service" ];
  #   # Defaults to 8080, but we are using it for traefik
  #   environment."HEALTH_CHECK_ADDR" = "0.0.0.0:8083";
  # };

  # globals.monitoring.http.firezone = {
  #   url = "https://firezone.${globals.domains.main}/";
  #   network = "external";
  #   expectedBodyRegex = "Welcome to Firezone";
  # };

  # globals.monitoring.http.firezone-api = {
  #   url = "https://firezone-api.${globals.domains.main}/healthz";
  #   network = "external";
  #   expectedBodyRegex = "ok";
  # };

  # consul.services.firezone = {
  #   port = config.services.firezone.server.web.port;
  #   tags = [
  #     "traefik.enable=true"
  #     "traefik.external=true"
  #     "traefik.http.routers.firezone.rule=Host(`firezone.${globals.domains.main}`) && PathPrefix(`/`)"
  #     "traefik.http.routers.firezone.entrypoints=websecure"
  #   ];
  # };

  # consul.services.firezone-api = {
  #   port = config.services.firezone.server.api.port;
  #   tags = [
  #     "traefik.enable=true"
  #     "traefik.external=true"
  #     "traefik.http.routers.firezone-api.rule=Host(`firezone-api.${globals.domains.main}`)"
  #     "traefik.http.routers.firezone-api.entrypoints=websecure"
  #   ];
  # };

  # globals.nebula.mesh.hosts.icarus.firewall.inbound = [
  #   {
  #     "port" = builtins.toString config.services.firezone.server.web.port;
  #     "proto" = "tcp";
  #     "group" = "reverse-proxy";
  #   }
  #   {
  #     "port" = builtins.toString config.services.firezone.server.api.port;
  #     "proto" = "tcp";
  #     "group" = "reverse-proxy";
  #   }
  # ];
}
