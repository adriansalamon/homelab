{
  imports = [
    ./authelia.nix
    ./lldap.nix
    ./webfinger
  ];

  # we need database access from the auth server
  globals.nebula.mesh.hosts.zeus.firewall.inbound = [
    {
      port = 5432;
      proto = "tcp";
      host = "zeus-auth";
    }
    {
      port = 6379;
      proto = "tcp";
      host = "zeus-auth";
    }
  ];
}
