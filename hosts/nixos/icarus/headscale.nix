{
  config,
  lib,
  pkgs,
  globals,
  nomadCfg,
  ...
}:
let
  inherit (lib)
    flip
    mapAttrsToList
    mapAttrs'
    ;

  nebulaIp = globals.nebula.mesh.hosts.icarus.ipv4;
  inernalDnsIps = flip mapAttrsToList globals.sites (
    _: site: lib.net.cidr.host 1 site.vlans.lan.cidrv4
  );

  format = pkgs.formats.json { };
  headscaleACL = format.generate "headscale-acl.json" {
    groups = {
      "group:salamon" = flip map globals.users (user: "${user}@${globals.domains.alt}");
    };

    tagOwners = {
      "tag:gateway" = [
        "group:salamon"
        "gateway@"
      ];
    };

    acls = [
      {
        action = "accept";
        src = [ "group:salamon" ];
        dst = flip mapAttrsToList globals.sites (_: siteCfg: "${siteCfg.vlans.lan.cidrv4}:*");
      }
      {
        action = "accept";
        src = [ "group:salamon" ];
        dst = [ "tag:gateway:*" ];
      }
      {
        action = "accept";
        src = [ "tag:gateway" ];
        dst = [ "${config.services.headscale.settings.prefixes.v4}:*" ];
      }
    ];

    autoApprovers = {
      routes = flip mapAttrs' globals.sites (
        _: siteCfg: {
          name = siteCfg.vlans.lan.cidrv4;
          value = [ "tag:gateway" ];
        }
      );
    };

    ssh = [
      {
        action = "accept";
        src = [ "group:salamon" ];
        dst = [ "tag:gateway" ];
        users = [ "autogroup:nonroot" ];
      }
    ];
  };

in
{
  # Mirror the original oidc secret
  age.secrets.headscale-oidc-client-secret = {
    inherit (nomadCfg.config.age.secrets.headscale-oidc-client-secret) rekeyFile;
    owner = "headscale";
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/headscale";
      mode = "0700";
    }
  ];

  services.headscale = {
    enable = true;
    address = nebulaIp;
    port = 8081;

    settings = {
      server_url = "https://headscale.${globals.domains.main}";

      database = {
        type = "sqlite";
        sqlite.path = "/var/lib/headscale/db.sqlite";
      };

      oidc = {
        issuer = "https://auth.${globals.domains.main}";
        client_id = "headscale";
        client_secret_path = config.age.secrets.headscale-oidc-client-secret.path;
        scope = [
          "openid"
          "profile"
          "email"
          "groups"
        ];
        extra_params = {
          domain_hint = globals.domains.alt;
        };
      };

      policy = {
        mode = "file";
        path = headscaleACL;
      };

      dns = {
        magic_dns = true;
        base_domain = "${globals.domains.ts}";
        override_local_dns = true;

        nameservers = {
          global = [
            "1.1.1.1"
            "1.0.0.1"
            "2606:4700:4700::1111"
            "2606:4700:4700::1001"
          ];

          split = {
            "local.${globals.domains.main}" = inernalDnsIps;
            "internal" = inernalDnsIps;
          };
        };
      };
    };
  };

  globals.monitoring.http.headscale = {
    url = "https://headscale.${globals.domains.main}/health";
    network = "external";
    expectedBodyRegex = "pass";
  };

  consul.services.headscale = {
    inherit (config.services.headscale) port;
    tags = [
      "traefik.enable=true"
      "traefik.external=true"
      "traefik.http.routers.headscale.rule=Host(`headscale.${globals.domains.main}`)"
      "traefik.http.routers.headscale.entrypoints=websecure"
    ];
  };

  globals.nebula.mesh.hosts.icarus.firewall.inbound = [
    {
      "port" = builtins.toString config.services.headscale.port;
      "proto" = "tcp";
      "group" = "reverse-proxy";
    }
  ];
}
