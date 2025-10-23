{
  config,
  lib,
  globals,
  profiles,
  ...
}:
let
  site = config.node.site;
  mkInternalRules = import profiles.router.coredns.internal { inherit config lib globals; };
in
{
  services.resolved.enable = false;

  environment.etc."resolv.conf".text = ''
    nameserver 127.0.0.1
  '';

  services.coredns = {
    enable = true;

    config = ''
      ${mkInternalRules (zone: zone)}

      . {
          log
          errors

          # Default public resolution
          forward . tls://1.1.1.1:853 tls://1.0.0.1:853 tls://9.9.9.9:853
      }
    '';
  };

  consul.services."traefik-${site}" = {
    address = lib.net.cidr.host 1 globals.sites.${site}.vlans.lan.cidrv4;
  };
}
