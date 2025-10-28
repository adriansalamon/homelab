{ lib, ... }:
{
  imports = lib.collect builtins.isPath (lib.filterAttrs (n: _: n != "default") (lib.rakeLeaves ./.));

  options.meta.usenftables = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };
}
