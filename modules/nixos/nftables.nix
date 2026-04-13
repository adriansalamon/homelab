{ config, lib, ... }:
{
  options.helpers.nftables = {
    mkMasqueradeRule = lib.mkOption {
      type = lib.types.unspecified;
      internal = true;
      readOnly = true;
      default = name: sourceZones: targetZones: {
        ${name} = {
          after = [ "hook" ];
          late = true;
          rules = lib.flatten (
            lib.forEach sourceZones (
              sourceZone:
              lib.forEach targetZones (
                targetZone:
                lib.concatStringsSep " " [
                  (lib.head config.networking.nftables.firewall.zones.${sourceZone}.ingressExpression)
                  (lib.head config.networking.nftables.firewall.zones.${targetZone}.egressExpression)
                  "masquerade"
                ]
              )
            )
          );
        };
      };
    };
  };
}
