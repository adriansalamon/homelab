# Function to generate internal rules for coredns
{
  config,
  lib,
  globals,
}:
zonesFn:
let
  consulIp = "127.0.0.1";

  snippets = ''
    (internal) {
        log
        errors
        # Rewrite to ddns consul
        rewrite stop name regex (.*)\.internal kea-ddns.{1}.service.consul answer auto
    }

    (local) {
        log
        errors

        # First: rewrite traefik-<site>.local.<domain> → traefik-<site>.service.consul
        rewrite stop name regex traefik-(.*)\.local\.${lib.escapeRegex globals.domains.main} traefik-{1}.service.consul answer auto

        # Else: rewrite <anything>.local.<domain> -> traefik-<site>.service.consul the site traefik
        rewrite stop name regex (.*)\.local\.${lib.escapeRegex globals.domains.main} traefik-${config.node.site}.service.consul answer auto
    }

    (domain) {
        log
        errors
        # Rewrite <anything>.<domain> → traefik-<site>.service.consul for internal reverse proxy
        rewrite stop name regex (.*)\.${lib.escapeRegex globals.domains.main} traefik-${config.node.site}.service.consul answer auto
    }
  '';
in
''
  ${snippets}

  # Rewrite <anything>.internal → kea-ddns.<anything>.service.consul. This manages the DDNS.
  ${zonesFn "internal"} {
      import internal
      forward . ${consulIp}:8600
  }

  ${zonesFn "local.${globals.domains.main}"} {
    import local
    forward . ${consulIp}:8600
  }

  ${zonesFn "site.${globals.domains.main}"} {
      log
      errors
      forward . tls://1.1.1.1:853 tls://1.0.0.1:853 tls://9.9.9.9:853
  }

  ${zonesFn globals.domains.main} {
      import domain
      forward . ${consulIp}:8600
  }

  # Forward all consul queries to local consul agent
  ${zonesFn "consul"} {
      log
      errors
      forward . ${consulIp}:8600
  }
''
