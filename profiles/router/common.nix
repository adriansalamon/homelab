{ ... }:
{
  boot.kernel.sysctl = {
    # we are a router, yay!
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.src_valid_mark" = 1;
    "net.ipv6.conf.all.disable_ipv6" = 1;
  };

  networking = {
    useNetworkd = true;
    resolvconf.enable = false;
  };

  systemd.network.enable = true;
}
