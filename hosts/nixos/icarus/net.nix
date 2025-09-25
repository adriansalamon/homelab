{ ... }:
{

  node.publicIp = "135.181.152.36";

  networking.nftables.firewall.zones.untrusted.interfaces = [ "enp1s0" ];

  networking.useNetworkd = true;

  systemd.network.networks = {
    "10-wan" = {
      address = [ "2a01:4f9:c013:bec3::1" ];
      gateway = [ "fe80::1" ];
      matchConfig.MACAddress = "96:00:04:5b:ca:1a";
      networkConfig.IPv6PrivacyExtensions = "yes";
      networkConfig.DHCP = "yes";
    };
  };
}
