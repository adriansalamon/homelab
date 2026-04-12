{
  config,
  globals,
  ...
}:
{
  services.postgresql = {
    enable = true;
    enableTCPIP = true;

    authentication = ''
      local   all             postgres                                trust
      host    all             all       ${globals.nebula.mesh.cidrv4} scram-sha-256
    '';
  };

  consul.services.postgres = {
    inherit (config.services.postgresql) port;
  };

  globals.nebula.mesh.hosts.${config.node.name}.firewall.inbound = [
    {
      inherit (config.services.postgresql.settings) port;
      proto = "tcp";
      group = "postgres-client";
    }
  ];
}
