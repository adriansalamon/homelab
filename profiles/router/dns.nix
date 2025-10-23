{
  config,
  lib,
  globals,
  profiles,
  ...
}:
let
  site = config.node.site;
  mkInternalRules = import profiles.router.coredns.internal-rules { inherit config lib globals; };
in
{

  imports = [
    profiles.router.coredns.blocklist
  ];

  services.resolved.enable = false;

  environment.etc."resolv.conf".text = ''
    nameserver 127.0.0.1
  '';

  services.coredns = {
    enable = true;

    config = ''
      ${mkInternalRules (zone: zone)}

      . {
          errors
          cache
          metadata
          blocker /var/lib/coredns/blocklist.txt 1h abp empty
          log . "{common} {/blocker/request-blocked}"

          # Default public resolution
          forward . tls://1.1.1.1:853 tls://1.0.0.1:853 tls://9.9.9.9:853
      }
    '';
  };

  consul.services."traefik-${site}" = {
    address = lib.net.cidr.host 1 globals.sites.${site}.vlans.lan.cidrv4;
  };
}
