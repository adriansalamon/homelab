{ inputs, lib, ... }:
let
  allModules = lib.rakeLeaves ./.;
  modulesToImport = lib.filterAttrs (n: _: n != "default") allModules;
in
{
  imports = [ inputs.microvm.nixosModules.host ] ++ lib.collect builtins.isPath modulesToImport;
}
