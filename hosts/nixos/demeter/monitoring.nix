{
  config,
  ...
}:
let
  name = config.node.name;
in
{

  services.telegraf = {
    enable = true;

    extraConfig = {
      outputs.prometheus_client = {
        listen = ":9273";
      };

      inputs = {
        conntrack = { };
        cpu = { };
        disk = { };
        diskio = { };
        internal = { };
        interrupts = { };
        kernel = { };
        kernel_vmstat = { };
        linux_sysctl_fs = { };
        mem = { };
        net = {
          ignore_protocol_stats = true;
        };
        netstat = { };
        nstat = { };
        processes = { };
        swap = { };
        system = { };
        systemd_units = {
          unittype = "service";
        };
        temp = { };
        #sensors = { };
        zfs = { };
      };
    };
  };

  # register it in Consul
  consul.services."${name}-telegraf" = {
    port = 9273;
    tags = [ "prometheus.scrape=true" ];
  };

  # allow the prometheus scrape server to access
  globals.nebula.mesh.hosts.${name}.firewall.inbound = [
    {
      port = "9273";
      proto = "tcp";
      host = "zeus-prometheus";
    }
  ];
}
