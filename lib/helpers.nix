_inputs: final: prev:
let
  # From https://github.com/divnix/digga/blob/baa54f8641ee9128cdda8b508553284c331fc9f1/src/importers.nix#L61-L114
  rakeLeaves =
    /*
      Synopsis: rakeLeaves _path_

      Recursively collect the nix files of _path_ into attrs.

      Output Format:
      An attribute set where all `.nix` files and directories with `default.nix` in them
      are mapped to keys that are either the file with .nix stripped or the folder name.
      All other directories are recursed further into nested attribute sets with the same format.

      Example file structure:
      ```
      ./core/default.nix
      ./base.nix
      ./main/dev.nix
      ./main/os/default.nix
      ```

      Example output:
      ```
      {
      core = ./core;
      base = base.nix;
      main = {
        dev = ./main/dev.nix;
        os = ./main/os;
      };
      }
      ```
    */
    dirPath:
    let
      inherit (prev) lib;

      seive =
        file: type:
        # Only rake `.nix` files or directories
        (type == "regular" && lib.hasSuffix ".nix" file) || (type == "directory");

      collect = file: type: {
        name = lib.removeSuffix ".nix" file;
        value =
          let
            path = dirPath + "/${file}";
          in
          if (type == "regular") || (type == "directory" && builtins.pathExists (path + "/default.nix")) then
            path
          # recurse on directories that don't contain a `default.nix`
          else
            rakeLeaves path;
      };

      files = lib.filterAttrs seive (builtins.readDir dirPath);
    in
    lib.filterAttrs (n: v: v != { }) (lib.mapAttrs' collect files);

  time = rec {
    nanosecond = 1;
    microsecond = 1000 * nanosecond;
    millisecond = 1000 * microsecond;
    second = 1000 * millisecond;
    minute = 60 * second;
    hour = 60 * minute;
    day = 24 * hour;
    week = 7 * day;
  };

  mkNomadConfiguration =
    {
      modules,
      pkgs,
      lib ? pkgs.lib,
      inputs,
      extraSpecialArgs ? { },
    }:
    let
      module = lib.evalModules {
        specialArgs = {
          inherit pkgs lib inputs;
        }
        // extraSpecialArgs;

        modules = [
          inputs.agenix-rekey-to-sops.sopsModules.default
          ../modules/common/global.nix
          ../modules/nomad/default.nix
        ]
        ++ modules;
      };
    in
    {
      inherit (module) config;
    };

in
{
  lib = prev.lib // {

    keepAttrs =
      attrs: keys:
      builtins.listToAttrs (
        map (k: {
          name = k;
          value = attrs.${k};
        }) keys
      );

    helpers = {
      generateWithEnv =
        envName:
        (
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          ''
            echo -n "${envName}="
            ${decrypt} ${lib.escapeShellArg (lib.head deps).file}
          ''
        );
    };

    inherit rakeLeaves time mkNomadConfiguration;
    inherit (import ./time.nix) iso8601ToUnix;
  };
}
