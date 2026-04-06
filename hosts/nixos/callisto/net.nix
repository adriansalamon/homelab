{ ... }:
{
  networking.nftables.firewall.zones.untrusted.interfaces = [ "enu1u1u1" ];

  globals.nebula.mesh.hosts.callisto = {
    id = 11;
  };

  networking.firewall.allowedTCPPorts = [
    25 # smtp
    80
    443
    587 # Starttls
    993 # Imaps
    8080 # unifi inform
    1883 # mqtt
    2222 # forgejo ssh
  ];
}
