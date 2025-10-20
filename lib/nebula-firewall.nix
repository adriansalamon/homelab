_inputs: final: prev: {
  lib = prev.lib // {
    nebula-firewall = {
      consul-server = [
        {
          port = "8300-8302";
          proto = "tcp";
          group = "consul-server";
        }
        {
          port = "8301";
          proto = "udp";
          group = "consul-server";
        }
        {
          port = "8300-8301";
          proto = "tcp";
          group = "consul-client";
        }
        {
          port = "8301";
          proto = "udp";
          group = "consul-client";
        }
        {
          port = "8500";
          proto = "tcp";
          group = "consul-client";
        }
      ];
    };
  };
}
