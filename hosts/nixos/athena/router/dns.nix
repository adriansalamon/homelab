{
  config,
  lib,
  globals,
  profiles,
  ...
}:
let
  siteName = "olympus";
  site = globals.sites.${siteName};

  mkInternalRules = import profiles.router.coredns.internal { inherit config lib globals; };

  # We want internal rules on port 53 and 5301 (for external vpn)
  mkDual = pattern: "${pattern}.:53 ${pattern}.:5301";
in
{
  environment.etc."resolv.conf".text = ''
    nameserver 127.0.0.1
  '';

  services.resolved.enable = false;
  services.coredns = {
    enable = true;
    # VPN network dns clients can only use DNS queries on port 5301
    config = ''
      ${mkInternalRules mkDual}

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
