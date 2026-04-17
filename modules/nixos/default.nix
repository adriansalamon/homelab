{ lib, ... }:
let
  allModules = lib.rakeLeaves ./.;
  modulesToImport = lib.filterAttrs (n: _: n != "default") allModules;
in
{
  imports = lib.collect builtins.isPath modulesToImport;

  options.meta.usenftables = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };
}
