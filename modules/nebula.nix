{
  inputs,
  config,
  nodes,
  lib,
  globals,
  ...
}:
let
  inherit (lib)
    mkIf
    concatLists
    flip
    mapAttrsToList
    count
    concatMapAttrs
    mapAttrs
    filterAttrs
    any
    attrValues
    attrNames
    mapAttrs'
    nameValuePair
    ;

  memberNets = filterAttrs (
    _: cfg: any (x: x == config.node.name) (attrNames cfg.hosts)
  ) globals.nebula;

in
{
  assertions = concatLists (
    flip mapAttrsToList memberNets (
      name: cfg:
      let
        assertionPrefix = "While evaluation the nebula network ${name}:";
        hostCfg = cfg.hosts.${config.node.name};
      in
      [
        {
          assertion = cfg.cidrv4 != null;
          message = "${assertionPrefix}: cidrv4 has to be set.";
        }
        {
          assertion = (count (x: x.lighthouse) (attrValues cfg.hosts)) >= 1;
          message = "${assertionPrefix}: You have to declare at least one lighthouse node.";
        }
        {
          assertion = (count (x: x.id == hostCfg.id) (attrValues cfg.hosts)) == 1;
          message = "${assertionPrefix}: More than one host with id ${toString hostCfg.id}";
        }
      ]
    )
  );

  age.secrets = flip concatMapAttrs memberNets (
    name: cfg:
    let
      caKeyPath = inputs.self.outPath + "/secrets/nebula/mesh/ca.key.age";
      caCertPath = inputs.self.outPath + "/secrets/nebula/mesh/ca.crt";
      hostCfg = cfg.hosts.${config.node.name};
      ipv4cidr = lib.net.cidr.withCidr hostCfg.ipv4 cfg.cidrv4;
    in

    {
      "nebula-${name}.key" = {
        owner = "nebula-${name}";
        group = "nebula-${name}";
        generator.script =
          {
            pkgs,
            file,
            decrypt,
            ...
          }:
          let
            pubkeyPath = lib.escapeShellArg (lib.removeSuffix ".key.age" file + ".crt");
          in
          # Using modified nebula-keygen-age. It generates private key to stdout, which we can then encrypt with age.
          # Also, we need to sign the public key with the CA key, which we can pipe to stdin of the nebula-keygen-age.
          ''
            priv=$(${pkgs.nebula-keygen-age}/bin/nebula-keygen-age genkey -out-pub ${pubkeyPath})
            ${decrypt} ${lib.escapeShellArg caKeyPath} \
              | ${pkgs.nebula-keygen-age}/bin/nebula-keygen-age sign -name ${config.node.name} -ip "${ipv4cidr}" \
                -subnets ${lib.escapeShellArg (builtins.concatStringsSep "," hostCfg.routeSubnets)} \
                -groups ${lib.escapeShellArg (builtins.concatStringsSep "," hostCfg.groups)} \
                -ca-crt ${lib.escapeShellArg caCertPath} -in-pub ${pubkeyPath} -out-crt ${pubkeyPath}
            echo "$priv"
          '';
      };
    }
  );

  networking.firewall.trustedInterfaces = flip mapAttrsToList memberNets (name: _: "nebula.${name}");

  services.nebula.networks = flip mapAttrs memberNets (
    name: cfg:
    let
      hostCfg = cfg.hosts.${config.node.name};
      lighthouses = filterAttrs (_: v: v.lighthouse) cfg.hosts;

      externalAddrs = name: [ "${nodes.${name}.config.node.publicIp}:4242" ];
    in
    {
      enable = true;
      ca = inputs.self.outPath + "/secrets/nebula/${name}/ca.crt";
      cert = lib.removeSuffix ".key.age" config.age.secrets."nebula-${name}.key".rekeyFile + ".crt";
      key = config.age.secrets."nebula-${name}.key".path;

      isLighthouse = hostCfg.lighthouse;

      lighthouses = mkIf (!hostCfg.lighthouse) (
        mapAttrsToList (_: lightHouseCfg: lightHouseCfg.ipv4) lighthouses
      );

      staticHostMap = mkIf (!hostCfg.lighthouse) (
        mapAttrs' (name: lighthouseCfg: nameValuePair (lighthouseCfg.ipv4) (externalAddrs name)) lighthouses
      );

      # Default to allow all outbound
      firewall.outbound = [
        {
          port = "any";
          proto = "any";
          host = "any";
          cidr = "0.0.0.0/0";
        }
      ] ++ hostCfg.firewall.outbound;

      # Default to allow icmp + ssh
      firewall.inbound = [
        {
          port = "any";
          proto = "icmp";
          host = "any";
          cidr = "0.0.0.0/0";
        }
        {
          port = "22";
          proto = "tcp";
          host = "any";
          cidr = "0.0.0.0/0";
        }
      ] ++ hostCfg.firewall.inbound;
    }
    // hostCfg.config
  );
}
