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
              nomadCfg = config.nomadConfigurations.homelab;
            };
            modules = [
              ../modules/common/global.nix
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
                      ++ [
                        (builtins.addErrorContext "while aggregating globals from nomad into flake-level globals:" config.nomadConfigurations.homelab.config._globalsDefs)
                      ]
                    )
                  );
                }
              )
            ];
          };

        in
        {

          inherit (eval.config.globals)
            admin-user
            sites
            nebula
            loki-secrets
            domains
            deploy
            users
            hetzner
            monitoring
            consul-servers
            databases
            ;
        };
    };
}
