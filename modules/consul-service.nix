{ lib, config, ... }:

let
  inherit (lib)
    mkOption
    types
    mapAttrsToList
    literalExpression
    ;

  svcToFile = id: attrs: {
    name = "consul.d/${id}.json";
    value.text = builtins.toJSON {
      service = {
        inherit id;
        name = attrs.name or id;
      }
      // (builtins.removeAttrs attrs [ "name" ]);
    };
  };
in
{

  options.consul.services = mkOption {
    type = types.attrsOf types.attrs;
    default = { };
    description = ''
      Map of additional Consul services. The attribute name becomes the service name.
      The value should be an attrset which gets converted to a consul JSON service definition.
    '';
    example = literalExpression ''
      {
        "jellyfin" = {
          port = 8096;
          tags = [ "traefik.enable=true" ];
        };
        "jellyfin-metrics" = {
          name = "jellyfin";
          port = 9001;
          tags = [ "prometheus.scrape=true" ];
        };
      }
    '';
  };

  config.environment.etc = lib.mkIf config.services.consul.enable (
    builtins.listToAttrs (mapAttrsToList svcToFile config.consul.services)
  );
}
