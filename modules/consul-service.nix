{ lib, config, ... }:

let
  inherit (lib)
    mkOption
    types
    mapAttrsToList
    literalExpression
    ;

  svcToFile = name: attrs: {
    name = "consul.d/${name}.json";
    value.text = builtins.toJSON {
      service = {
        id = name;
        name = name;
      }
      // attrs;
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
      }
    '';
  };

  config.environment.etc = lib.mkIf config.services.consul.enable (
    builtins.listToAttrs (mapAttrsToList svcToFile config.consul.services)
  );
}
