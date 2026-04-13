{ lib, ... }:
let
  allModules = lib.rakeLeaves ./.;
  # Filter out guests module - it will be imported conditionally by hosts that need it
  modulesToImport = lib.filterAttrs (n: _: n != "default" && n != "guests") allModules;
in
{
  imports = lib.collect builtins.isPath modulesToImport;

  options.meta.usenftables = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };
}
