{ inputs, ... }:
{
  flake =
    { config, lib, ... }:
    {

      globals =
        let
          eval = lib.evalModules {
            prefix = [ "globals" ];
            specialArgs = {
              inherit (inputs.self.pkgs.x86_64-linux) lib;
              inherit inputs;
              inherit (config) nodes;
            };
            modules = [
              ../modules/global.nix
              ../global.nix
            ]
            ++ [
              (
                { lib, ... }:
                {
                  globals = lib.mkMerge (
                    lib.concatLists (
                      lib.flip lib.mapAttrsToList config.nodes (
                        name: cfg:
                        builtins.addErrorContext "while aggregating globals from nixosConfigurations.${name} into flake-level globals:" cfg.config._globalsDefs
                      )
                    )
                  );
                }
              )
            ];
          };

        in
        {

          inherit (eval.config.globals)
            sites
            nebula
            loki-secrets
            domains
            deploy
            users
            ;
        };
    };
}
