{ inputs, ... }:

{
  flake =
    { config, lib, ... }:
    let
      inherit (lib)
        concatMapAttrs
        mapAttrs'
        flip
        nameValuePair
        ;

      mkHost =
        name: hostConfig:
        let
          pkgs = config.pkgs.x86_64-linux;
          profiles = pkgs.lib.rakeLeaves ../profiles;
        in
        {
          nixosConfigurations.${name} = inputs.nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = {
              inherit (inputs) agenix;
              inherit inputs;
              inherit (pkgs) lib;
              inherit (config) nodes globals;
              inherit profiles;
              nomadCfg = config.homeConfigurations.nomad;
            };
            modules = [
              inputs.microvm.nixosModules.host
              ../modules/guests
              ../hosts/nixos/${name}
              {
                nixpkgs.config.allowUnfree = true;
                node = {
                  name = name;
                  secretsDir = ../hosts/nixos/${name}/secrets;
                };
                networking.hostName = name;
                nixpkgs.overlays = (import ../pkgs/default.nix inputs) ++ [ (import ../lib inputs) ];
              }
            ];
          };

        };

      mkDarwin =
        name: nixpkgsVersion: extraModules:
        let
          pkgs = config.pkgs.aarch64-darwin;
        in
        {
          darwinConfigurations.${name} = inputs.nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            specialArgs = {
              inherit inputs;
              inherit (inputs) agenix;
              inherit (pkgs) lib;
              inherit (config) nodes globals;
            };
            modules = [
              inputs.agenix.darwinModules.default
              #{ nix.linux-builder.enable = true; }
              inputs.nix-rosetta-builder.darwinModules.default
              {
                nix-rosetta-builder.onDemand = true;
                nix-rosetta-builder.enable = true;
              }
              ../hosts/darwin
              ../hosts/darwin/atlas
              inputs.home-manager.darwinModules.home-manager
              {
                home-manager.users.asalamon.imports = [
                  inputs.agenix.homeManagerModules.default
                  ../users/asalamon
                ];

                nixpkgs.overlays = (import ../pkgs/default.nix inputs) ++ [ (import ../lib inputs) ];
              }
            ];
          };
        };

      mkMerge = builtins.foldl' (a: b: inputs.nixpkgs.lib.attrsets.recursiveUpdate a b) { };

      hosts = mkMerge [
        (mkHost "orpheus" { })
        (mkHost "athena" { })
        (mkHost "zeus" { })
        (mkHost "demeter" { })
        (mkHost "icarus" { })
        (mkHost "charon" { })
        (mkHost "pythia" { })
        (mkHost "hermes" { })
        (mkHost "penelope" { })
        (mkHost "pan" { })
        (mkDarwin "atlas" inputs.nixpkgs [ ])
      ];
    in
    hosts
    // {
      guestConfigs = flip concatMapAttrs config.nixosConfigurations (
        _: node:
        flip mapAttrs' (node.config.guests or { }) (
          guestName: guestDef: nameValuePair guestDef.name node.config.microvm.vms.${guestName}.config
        )
      );

      nodes = config.nixosConfigurations // config.guestConfigs;

      deploy.nodes =
        flip lib.mapAttrs
          (lib.filterAttrs (n: cfg: cfg.config.node.dummy == false) config.nixosConfigurations)
          (
            name: cfg:
            let
              system = "x86_64-linux";
              deployCfg = config.globals.deploy.${name};
            in
            {
              hostname = deployCfg.ip;
              profiles.system = {
                user = "root";
                sshUser = "nixos";
                path = inputs.deploy-rs.lib.${system}.activate.nixos cfg;
              };
              sshOpts = deployCfg.sshOpts or [ ];
              deploy.remoteBuild = true;
            }
          );
    };
}
