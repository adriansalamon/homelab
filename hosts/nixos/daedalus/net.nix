_: {
  networking.useNetworkd = true;
  networking.nftables.firewall.zones.untrusted.interfaces = [ "enp1s0" ];

  systemd.network.networks."10-wan" = {
    matchConfig.Name = "enp1s0";
    networkConfig.DHCP = "yes";
    networkConfig.IPv6PrivacyExtensions = "yes";
  };

  # initrd needs its own network config — runtime systemd.network is not carried over
  boot.initrd.systemd.network.networks."10-wan" = {
    matchConfig.Name = "enp1s0";
    networkConfig.DHCP = "yes";
  };
}
