{
  inputs,
  lib,
  config,
  globals,
  ...
}:
let
  nebulaIp = globals.nebula.mesh.hosts.athena.ipv4;
  siteName = "olympus";
  site = globals.sites.${siteName};
in
{

  age.secrets.consul-token = {
    rekeyFile = inputs.self.outPath + "/secrets/consul/kea-ddns-token.age";
    owner = "kea-ddns-consul";
  };

  services.kea-ddns-consul = {
    enable = true;
    consulTokenFile = config.age.secrets.consul-token.path;
    consulUrl = "http://${nebulaIp}:8500";
  };

  environment.etc."resolv.conf".text = ''
    nameserver 127.0.0.1
  '';

  # TODO: Clean up this mess of a DNS config, and add some ad-blocking (eg. AdGuard)
  services.resolved.enable = false;
  services.coredns = {
    enable = true;
    # VPN network dns clients can only use DNS queries on port 5301
    config = ''
      # Rewrite <anything>.internal → kea-ddns.<anything>.service.consul. This manages the DDNS.
      internal.:53 {
          log
          errors
          rewrite stop name regex (.*)\.internal kea-ddns.{1}.service.consul answer auto
          forward . ${nebulaIp}:8600
      }

      internal.:5301 {
          log
          errors
          rewrite stop name regex (.*)\.internal kea-ddns.{1}.service.consul answer auto
          forward . ${nebulaIp}:8600
      }

      # Rewrite <anything>.local.${globals.domains.main} → traefik-${siteName}.service.consul for internal reverse proxy
      local.${globals.domains.main}.:53 {
          log
          errors
          rewrite stop name regex (.*)\.local\.${lib.escapeRegex globals.domains.main} traefik-${siteName}.service.consul answer auto
          forward . ${nebulaIp}:8600
      }

      local.${globals.domains.main}.:5301 {
          log
          errors
          rewrite stop name regex (.*)\.local\.${lib.escapeRegex globals.domains.main} traefik-${siteName}.service.consul answer auto
          forward . ${nebulaIp}:8600
      }

      # Rewrite <anything>.local.${globals.domains.main} → traefik-${siteName}.service.consul for internal reverse proxy
      ${globals.domains.main}.:53 {
          log
          errors
          rewrite stop name regex (.*)\.${lib.escapeRegex globals.domains.main} traefik-${siteName}.service.consul answer auto
          forward . ${nebulaIp}:8600
      }

      ${globals.domains.main}.:5301 {
          log
          errors
          rewrite stop name regex (.*)\.${lib.escapeRegex globals.domains.main} traefik-${siteName}.service.consul answer auto
          forward . ${nebulaIp}:8600
      }

      # Forward all consul queries to local consul agent
      consul.:53 {
          log
          errors
          forward . ${nebulaIp}:8600
      }

      consul.:5301 {
          log
          errors
          forward . ${nebulaIp}:8600
      }

      .:53 {
          log
          errors
          cache
          acl {
              drop net ${site.vlans.external-vpn.cidrv4} # Block vpn network
          }

          forward . tls://1.1.1.1:853 tls://1.0.0.1:853 tls://9.9.9.9:853
      }

      # VPN network dns inside wireguard
      .:5301 {
          acl {
              allow net ${site.vlans.external-vpn.cidrv4}
              drop
          }
          cache
          log
          errors
          forward . dns://10.128.0.1:53
      }
    '';
  };

  consul.services."traefik-${siteName}" = {
    address = lib.net.cidr.host 1 globals.sites.${siteName}.vlans.lan.cidrv4;
  };
}
