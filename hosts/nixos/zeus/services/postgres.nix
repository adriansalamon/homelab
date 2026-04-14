{
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
}
