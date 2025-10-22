{
  config,
  lib,
  globals,
  ...
}:
let
  site = globals.sites.${config.node.site};

  inherit (lib)
    mkIf
    flip
    mapAttrs'
    concatMapAttrs
    filterAttrs
    mapAttrsToList
    ;

  cfg = config.networking.nftables.firewall;

  vlanZones = flip mapAttrs' site.vlans (
    name: cfg: {
      name = "vlan-${name}";
      value = cfg;
    }
  );

  trustedZones =
    builtins.attrNames (filterAttrs (_: cfg: cfg.trusted) vlanZones)
    ++ lib.optional (lib.hasAttr "lan" cfg.zones) "lan"
    ++ [ "tailscale" ];

  internetZones = builtins.attrNames vlanZones ++ lib.optional (lib.hasAttr "lan" cfg.zones) "lan";

  otherSitesLans = mapAttrsToList (_: siteCfg: siteCfg.vlans.lan.cidrv4) (
    filterAttrs (siteName: siteCfg: siteName != config.node.site) globals.sites
  );
in
{
  # Common firewall config, needs zones defined: wan

  networking.nftables = {
    enable = true;

    firewall = {
      zones = {
        other-sites-lan = {
          ingressExpression = flip map otherSitesLans (cidrv4: "iifname nebula.mesh ip saddr ${cidrv4}");
          egressExpression = flip map otherSitesLans (cidrv4: "oifname nebula.mesh ip daddr ${cidrv4}");
        };

        tailscale = {
          interfaces = [ config.services.tailscale.interfaceName ];
        };
      }
      // concatMapAttrs (vlanName: _: {
        "vlan-${vlanName}".interfaces = [ vlanName ];
      }) site.vlans;

      rules = {
        masquerade-internet = {
          from = internetZones;
          to = [ "wan" ];
          # We do our own masquerading without `masquerade random` because
          # nebula has a hard time to establish connections with it enabled
          # masquerade = true;
          late = true; # Only accept after any rejects have been processed
          verdict = "accept";
        };

        # Allow dns from all trusted vlans
        allow-dns = {
          from = trustedZones;
          to = [ "local" ];
          allowedTCPPorts = [ 53 ];
          allowedUDPPorts = [ 53 ];
        };

        # Allow access to the reverse proxy from lan devices
        allow-reverse-proxy = {
          from = trustedZones;
          to = [ "local" ];
          allowedTCPPorts = [
            80
            443
            8080 # unifi inform
            1883 # mqtt
            2222 # forgejo ssh
          ];
        };

        allow-server-communication = mkIf (lib.hasAttr "vlan-server" cfg.zones) {
          from = [ "vlan-server" ];
          to = [ "vlan-lan" ];
          verdict = "accept";
        };

        disallow-wan-ssh = {
          from = [ "wan" ];
          to = [ "local" ];
          early = true;
          extraLines = [
            "tcp dport 22 drop"
          ];
        };

        allow-site-to-site-lan = {
          from = [ "vlan-lan" ];
          to = [ "other-sites-lan" ];
          verdict = "accept";
        };

        # tailscale
        allow-tailscale-to-lan = {
          from = [ "tailscale" ];
          to = [ "vlan-lan" ];
          verdict = "accept";
        };

        allow-lan-to-tailscale = {
          from = [ "vlan-lan" ];
          to = [ "tailscale" ];
          verdict = "accept";
        };
      };
    };

    chains = {
      output = {
        allow-all = {
          after = [ "hook" ];
          rules = [ "type filter hook output priority 0; policy accept;" ];
        };
      };

      postrouting = lib.mkMerge [
        (config.helpers.nftables.mkMasqueradeRule "masquerade-internet" internetZones [
          "wan"
        ])
      ];
    };
  };
}
