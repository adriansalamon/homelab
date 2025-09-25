{
  config,
  lib,
  inputs,
  globals,
  ...
}:
{

  age.secrets.kea-ddns-consul-token = {
    rekeyFile = inputs.self.outPath + "/secrets/consul/kea-ddns-token.age";
    owner = "kea-ddns-consul";
  };

  services.kea-ddns-consul = {
    enable = true;
    consulTokenFile = config.age.secrets.kea-ddns-consul-token.path;
    consulUrl = "http://127.0.0.1:8500";
  };

  services.resolved.enable = false;

  environment.etc."resolv.conf".text = ''
    nameserver 127.0.0.1
  '';

  services.coredns = {
    enable = true;

    config = ''
      # Rewrite <anything>.internal → kea-ddns.<anything>.service.consul. This manages the DDNS.
      internal {
          log
          errors
          rewrite stop name regex (.*)\.internal kea-ddns.{1}.service.consul answer auto
          forward . 127.0.0.1:8600
      }

      # Rewrite <anything>.local.${globals.domains.main} → traefik-delphi.service.consul for internal reverse proxy
      local.${globals.domains.main} {
          log
          errors
          rewrite stop name regex (.*)\.local\.${lib.escapeRegex globals.domains.main} traefik-delphi.service.consul answer auto
          forward . 127.0.0.1:8600
      }

      site.${globals.domains.main} {
          log
          errors
          forward . tls://1.1.1.1:853 tls://1.0.0.1:853 tls://9.9.9.9:853
      }

      # Rewrite <anything>.${globals.domains.main} → traefik-delphi.service.consul for internal reverse proxy
      ${globals.domains.main} {
          log
          errors
          rewrite stop name regex (.*)\.${lib.escapeRegex globals.domains.main} traefik-delphi.service.consul answer auto
          forward . 127.0.0.1:8600
      }

      # Forward all consul queries to local consul agent
      consul {
          log
          errors
          forward . 127.0.0.1:8600
      }

      . {
          log
          errors

          # Default public resolution
          forward . tls://1.1.1.1:853 tls://1.0.0.1:853 tls://9.9.9.9:853
      }
    '';
  };

  consul.services.traefik-delphi = {
    address = lib.net.cidr.host 1 globals.sites.delphi.vlans.lan.cidrv4;
  };
}
