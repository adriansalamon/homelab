{ lib, ... }:
{
  options.node = {
    name = lib.mkOption {
      description = "Name of the node.";
      type = lib.types.str;
    };

    secretsDir = lib.mkOption {
      description = "Path to the secrets directory for this node.";
      type = lib.types.path;
    };

    publicIp = lib.mkOption {
      description = "Public IP address of the node.";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    id = lib.mkOption {
      description = "ID of the node. Used for static IP assignment inside nebula.";
      type = lib.types.int;
    };
  };
}
