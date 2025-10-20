{
  config,
  lib,
  globals,
  ...
}:
let
  inherit (lib)
    net
    flip
    mapAttrsToList
    ;

  site = globals.sites.${config.node.site};
in
{
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config = {
        interfaces = flip mapAttrsToList site.vlans (name: _: name);
      };

      subnet4 = flip mapAttrsToList site.vlans (
        name: vlanCfg: {
          inherit (vlanCfg) id;
          subnet = vlanCfg.cidrv4;
          pools = [ { pool = "${net.cidr.host 100 vlanCfg.cidrv4} - ${net.cidr.host 200 vlanCfg.cidrv4}"; } ];

          option-data =
            let
              dnsServer = if vlanCfg.trusted then net.cidr.host 1 vlanCfg.cidrv4 else "1.1.1.1, 1.0.0.1";
            in
            [
              {
                name = "routers";
                data = net.cidr.host 1 vlanCfg.cidrv4;
              }
              {
                name = "domain-name-servers";
                data = dnsServer;
              }
            ];

          reservations = lib.concatLists (
            lib.forEach (builtins.attrValues vlanCfg.hosts) (
              hostCfg:
              lib.optional (hostCfg.mac != null) {
                hw-address = hostCfg.mac;
                ip-address = hostCfg.ipv4;
              }
            )
          );
        }
      );

      # Sent to the kea-ddns-consul service, that will publish these as services in consul
      dhcp-ddns = {
        enable-updates = true;
        server-ip = "127.0.0.1";
        server-port = 53010;
        sender-ip = "";
        sender-port = 0;
        max-queue-size = 1024;
        ncr-protocol = "UDP";
        ncr-format = "JSON";
      };

      ddns-send-updates = true;
      ddns-override-no-update = true;
      ddns-override-client-update = true;
      ddns-replace-client-name = "never";
      ddns-qualifying-suffix = "";
      ddns-update-on-renew = true;
    };
  };
}
