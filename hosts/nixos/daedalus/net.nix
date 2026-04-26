_:
{
  networking.useNetworkd = true;
  networking.nftables.firewall.zones.untrusted.interfaces = [ "enp1s0" ];

  # WAN: standalone public IP from Hetzner DHCP
  systemd.network.networks."10-wan" = {
    matchConfig.Name = "enp1s0";
    networkConfig = {
      DHCP = "yes";
      IPv6PrivacyExtensions = "yes";
    };
  };

  # Internal bridge for container guests — no physical uplink (avoids cloud MAC filtering)
  systemd.network.netdevs."20-serverBr" = {
    netdevConfig = {
      Kind = "bridge";
      Name = "serverBr";
    };
  };

  systemd.network.networks."20-serverBr" = {
    matchConfig.Name = "serverBr";
    address = [ "172.16.0.1/24" ];
    # Masquerade here so 172.16.0.0/24 is added to masq_saddr, not enp1s0's own IP
    networkConfig.IPMasquerade = "ipv4";
  };

  # IP forwarding for container NAT
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = true;

  # initrd needs its own network config — runtime systemd.network is not carried over
  boot.initrd.systemd.network.networks."10-wan" = {
    matchConfig.Name = "enp1s0";
    networkConfig.DHCP = "yes";
  };

  networking.nftables.firewall.zones.bridge.interfaces = [ "serverBr" ];

  networking.nftables.firewall.rules.container-to-wan = {
    from = [ "bridge" ];
    to = [ "untrusted" ]; # enp1s0
    verdict = "accept";
  };
}
