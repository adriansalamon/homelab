{
  inputs,
  config,
  nodes,
  lib,
  pkgs,
  globals,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    mkForce
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

  nebulaCfg = config.services.nebula;
  enabledNetworks = lib.filterAttrs (n: v: v.enable) nebulaCfg.networks;

  resolveFinalPort =
    netCfg:
    if netCfg.listen.port == null then
      if (netCfg.isLighthouse || netCfg.isRelay) then 4242 else 0
    else
      netCfg.listen.port;

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
        generator = {
          tags = [ "nebula-cert" ];
          script =
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
              pub_path=$(mktemp)
              priv=$(${pkgs.nebula-keygen-age}/bin/nebula-keygen-age genkey -out-pub $pub_path)
              ${decrypt} ${lib.escapeShellArg caKeyPath} \
                | ${pkgs.nebula-keygen-age}/bin/nebula-keygen-age sign -name ${config.node.name} -ip "${ipv4cidr}" \
                  -subnets ${lib.escapeShellArg (builtins.concatStringsSep "," hostCfg.routeSubnets)} \
                  -groups ${lib.escapeShellArg (builtins.concatStringsSep "," hostCfg.groups)} \
                  -ca-crt ${lib.escapeShellArg caCertPath} -version 1 -in-pub $pub_path -out-crt ${pubkeyPath}.v1
              ${decrypt} ${lib.escapeShellArg caKeyPath} \
                | ${pkgs.nebula-keygen-age}/bin/nebula-keygen-age sign -name ${config.node.name} -ip "${ipv4cidr}" \
                  -subnets ${lib.escapeShellArg (builtins.concatStringsSep "," hostCfg.routeSubnets)} \
                  -groups ${lib.escapeShellArg (builtins.concatStringsSep "," hostCfg.groups)} \
                  -ca-crt ${lib.escapeShellArg caCertPath} -version 2 -in-pub $pub_path -out-crt ${pubkeyPath}.v2
              cat ${pubkeyPath}.v1 ${pubkeyPath}.v2 > ${pubkeyPath}
              rm ${pubkeyPath}.v1 ${pubkeyPath}.v2 $pub_path
              echo "$priv"
            '';
        };
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
      ca = inputs.self.outPath + "/secrets/nebula/${name}/ca_combined.crt";
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
      ]
      ++ hostCfg.firewall.outbound;

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
      ]
      ++ hostCfg.firewall.inbound;
    }
    // hostCfg.config
  );

  # We want to predictable config in /etc/nebula, so we don't need to restart nebula on config change
  # Helps with deploying to systems that become unresponsive while nebula is restarting (e.g. with NFS mounts)
  environment.etc = mkMerge (
    flip mapAttrsToList enabledNetworks (
      netName: netCfg:
      let
        # from https://github.com/NixOS/nixpkgs/blob/76e269a01c66e539c6d76f0417913e25936d3b00/nixos/modules/services/networking/nebula.nix
        settings = lib.recursiveUpdate {
          pki = {
            ca = netCfg.ca;
            cert = netCfg.cert;
            key = netCfg.key;
          };
          static_host_map = netCfg.staticHostMap;
          lighthouse = {
            am_lighthouse = netCfg.isLighthouse;
            hosts = netCfg.lighthouses;
            serve_dns = netCfg.lighthouse.dns.enable;
            dns.host = netCfg.lighthouse.dns.host;
            dns.port = netCfg.lighthouse.dns.port;
          };
          relay = {
            am_relay = netCfg.isRelay;
            relays = netCfg.relays;
            use_relays = true;
          };
          listen = {
            host = netCfg.listen.host;
            port = resolveFinalPort netCfg;
          };
          tun = {
            disabled = netCfg.tun.disable;
            dev = if (netCfg.tun.device != null) then netCfg.tun.device else "nebula.${netName}";
          };
          firewall = {
            inbound = netCfg.firewall.inbound;
            outbound = netCfg.firewall.outbound;
          };
        } netCfg.settings;
        format = pkgs.formats.yaml { };
      in
      {
        "nebula/${netName}.yml".source = format.generate "nebula-${netName}.yml" settings;
      }
    )
  );

  # Reload instead of restarting nebula
  systemd.services = flip mapAttrs' enabledNetworks (
    netName: _: {
      name = "nebula@${netName}";
      value = {
        stopIfChanged = false;
        reloadTriggers = lib.singleton config.environment.etc."nebula/${netName}.yml".source;
        serviceConfig.ExecStart = mkForce "${pkgs.nebula}/bin/nebula -config /etc/nebula/${netName}.yml";
      };
    }
  );
}
