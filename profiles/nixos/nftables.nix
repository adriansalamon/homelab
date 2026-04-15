{
  config,
  lib,
  ...
}:

{

  config = lib.mkIf config.meta.usenftables {
    networking.firewall.trustedInterfaces = [ "lo" ];

    networking.nftables = {
      stopRuleset = lib.mkDefault ''
        table inet filter {
          chain input {
            type filter hook input priority filter; policy drop;
            ct state invalid drop
            ct state {established, related} accept

            iifname lo accept
            meta l4proto ipv6-icmp accept
            meta l4proto icmp accept
            ip protocol igmp accept
            tcp dport ${toString (lib.head config.services.openssh.ports)} accept
          }
          chain forward {
            type filter hook forward priority filter; policy drop;
          }
          chain output {
            type filter hook output priority filter; policy accept;
          }
        }
      '';

      firewall = {
        enable = true;
        localZoneName = "local";

        zones = {
          trusted-interfaces.interfaces = config.networking.firewall.trustedInterfaces;
        };

        snippets = {
          nnf-common.enable = false;
          nnf-conntrack.enable = true;
          nnf-drop.enable = true;
          nnf-loopback.enable = true;
          nnf-ssh.enable = true;
        };

        rules.untrusted-to-local = {
          from = [ "untrusted" ];
          to = [ "local" ];

          inherit (config.networking.firewall)
            allowedTCPPorts
            allowedTCPPortRanges
            allowedUDPPorts
            allowedUDPPortRanges
            ;
        };

        rules.trusted-interfaces-local = {
          from = [ "trusted-interfaces" ];
          to = [ "local" ];
          verdict = "accept";
        };

        rules.trusted-interfaces-to-all = {
          from = [ "trusted-interfaces" ];
          to = "all";
          verdict = "accept";
        };

        rules.icmp-and-igmp = {
          after = [
            "ct"
            "ssh"
          ];
          from = "all";
          to = [ "local" ];
          extraLines = [
            "meta l4proto ipv6-icmp accept"
            "meta l4proto icmp accept"
            "ip protocol igmp accept"
          ];
        };
      };
    };
  };
}
