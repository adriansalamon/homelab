{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatStringsSep
    types
    recursiveUpdate
    mapAttrs'
    nameValuePair
    mapAttrsToList
    filterAttrs
    mkOption
    mkIf
    mkMerge
    mkPackageOption
    literalExpression
    ;

  cfg = config.services.nebula;
  enabledNetworks = filterAttrs (n: v: v.enable) cfg.networks;

  genSettings =
    netName: netCfg:
    recursiveUpdate {
      pki = {
        ca = netCfg.ca;
        cert = netCfg.cert;
        key = netCfg.key;
      };
      static_host_map = netCfg.staticHostMap;
      lighthouse = {
        am_lighthouse = netCfg.isLighthouse;
        hosts = netCfg.lighthouses;
        serve_dns = netCfg.lighthouse.dns.enable;
        dns.host = netCfg.lighthouse.dns.host;
        dns.port = netCfg.lighthouse.dns.port;
      };
      relay = {
        am_relay = netCfg.isRelay;
        relays = netCfg.relays;
        use_relays = true;
      };
      listen = {
        host = netCfg.listen.host;
        port = resolveFinalPort netCfg;
      };
      tun = {
        disabled = netCfg.tun.disable;
        dev = if (netCfg.tun.device != null) then netCfg.tun.device else "nebula.${netName}";
      };
      firewall = {
        inbound = netCfg.firewall.inbound;
        outbound = netCfg.firewall.outbound;
      };
    } netCfg.settings;

  format = pkgs.formats.yaml { };

  genConfigFile = netName: settings: format.generate "nebula-config-${netName}.yml" settings;

  resolveFinalPort =
    netCfg:
    if netCfg.listen.port == null then
      if (netCfg.isLighthouse || netCfg.isRelay) then 4242 else 0
    else
      netCfg.listen.port;
in
{
  options = {
    services.nebula = {
      networks = mkOption {
        description = "Nebula network definitions.";
        default = { };
        type = types.attrsOf (
          types.submodule {
            options = {
              enable = mkOption {
                type = types.bool;
                default = true;
                description = "Enable or disable this network.";
              };

              package = mkPackageOption pkgs "nebula" { };

              ca = mkOption {
                type = types.path;
                description = "Path to the certificate authority certificate.";
                example = "/etc/nebula/ca.crt";
              };

              cert = mkOption {
                type = types.path;
                description = "Path to the host certificate.";
                example = "/etc/nebula/host.crt";
              };

              key = mkOption {
                type = types.oneOf [
                  types.nonEmptyStr
                  types.path
                ];
                description = "Path or reference to the host key.";
                example = "/etc/nebula/host.key";
              };

              enableReload = mkOption {
                type = types.bool;
                default = false;
                description = "Not implemented";
              };

              staticHostMap = mkOption {
                type = types.attrsOf (types.listOf (types.str));
                default = { };
                description = ''
                  The static host map defines a set of hosts with fixed IP addresses on the internet (or any network).
                  A host can have multiple fixed IP addresses defined here, and nebula will try each when establishing a tunnel.
                '';
                example = {
                  "192.168.100.1" = [ "100.64.22.11:4242" ];
                };
              };

              isLighthouse = mkOption {
                type = types.bool;
                default = false;
                description = "Whether this node is a lighthouse.";
              };

              isRelay = mkOption {
                type = types.bool;
                default = false;
                description = "Whether this node is a relay.";
              };

              lighthouse.dns.enable = mkOption {
                type = types.bool;
                default = false;
                description = "Whether this lighthouse node should serve DNS.";
              };

              lighthouse.dns.host = mkOption {
                type = types.str;
                default = "localhost";
                description = ''
                  IP address on which nebula lighthouse should serve DNS.
                  'localhost' is a good default to ensure the service does not listen on public interfaces;
                  use a Nebula address like 10.0.0.5 to make DNS resolution available to nebula hosts only.
                '';
              };

              lighthouse.dns.port = mkOption {
                type = types.nullOr types.port;
                default = 5353;
                description = "UDP port number for lighthouse DNS server.";
              };

              lighthouses = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = ''
                  List of IPs of lighthouse hosts this node should report to and query from. This should be empty on lighthouse
                  nodes. The IPs should be the lighthouse's Nebula IPs, not their external IPs.
                '';
                example = [ "192.168.100.1" ];
              };

              relays = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = ''
                  List of IPs of relays that this node should allow traffic from.
                '';
                example = [ "192.168.100.1" ];
              };

              listen.host = mkOption {
                type = types.str;
                default = "0.0.0.0";
                description = "IP address to listen on.";
              };

              listen.port = mkOption {
                type = types.nullOr types.port;
                default = null;
                defaultText = literalExpression ''
                  if (config.services.nebula.networks.''${name}.isLighthouse ||
                      config.services.nebula.networks.''${name}.isRelay) then
                    4242
                  else
                    0;
                '';
                description = "Port number to listen on.";
              };

              tun.disable = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  When tun is disabled, a lighthouse can be started without a local tun interface (and therefore without root).
                '';
              };

              tun.device = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Name of the tun device. Defaults to nebula.\${networkName}.";
              };

              firewall.outbound = mkOption {
                type = types.listOf types.attrs;
                default = [ ];
                description = "Firewall rules for outbound traffic.";
                example = [
                  {
                    port = "any";
                    proto = "any";
                    host = "any";
                  }
                ];
              };

              firewall.inbound = mkOption {
                type = types.listOf types.attrs;
                default = [ ];
                description = "Firewall rules for inbound traffic.";
                example = [
                  {
                    port = "any";
                    proto = "any";
                    host = "any";
                  }
                ];
              };

              settings = mkOption {
                type = format.type;
                default = { };
                description = ''
                  Nebula configuration. Refer to
                  <https://github.com/slackhq/nebula/blob/master/examples/config.yml>
                  for details on supported values.
                '';
                example = literalExpression ''
                  {
                    lighthouse.interval = 15;
                  }
                '';
              };
            };
          }
        );
      };
    };
  };

  config = mkIf (enabledNetworks != { }) {
    # Generate config files for each enabled network
    environment.etc = mkMerge (
      mapAttrsToList (netName: netCfg: {
        "nebula/${netName}.yml" = {
          source = genConfigFile netName (genSettings netName netCfg);
        };
      }) enabledNetworks
    );

    # Create launchd services for each network
    launchd.user.agents = mapAttrs' (
      netName: netCfg:
      nameValuePair "nebula-${netName}" {
        serviceConfig = {
          ProgramArguments = [
            "sudo"
            "${pkgs.nebula}/bin/nebula"
            "-config"
            "/etc/nebula/${netName}.yml"
          ];
          KeepAlive = true;
          RunAtLoad = true;
          StandardErrorPath = "/tmp/nebula-${netName}.err.log";
          StandardOutPath = "/tmp/nebula-${netName}.out.log";
        };
      }
    ) enabledNetworks;

    system.activationScripts.postActivation.text = ''
      echo "Reloading Nebula processes"
      ${builtins.concatStringsSep "\n" (
        lib.mapAttrsToList (netName: _: ''
          pkill -HUP -f "${pkgs.nebula}/bin/nebula -config /etc/nebula/${netName}.yml" || true
        '') enabledNetworks
      )}
    '';

    # Add sudo rules for each network
    security.sudo.extraConfig = concatStringsSep "\n" (
      mapAttrsToList (
        netName: netCfg:
        "%admin ALL=(root) NOPASSWD: ${pkgs.nebula}/bin/nebula -config /etc/nebula/${netName}.yml"
      ) enabledNetworks
    );
  };
}
