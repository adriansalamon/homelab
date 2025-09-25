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

      deployCfg = builtins.fromJSON (builtins.readFile ../deploy.json);

      mkHost =
        name: hostConfig:
        let
          pkgs = config.pkgs.x86_64-linux;
        in
        {
          nixosConfigurations.${name} = inputs.nixpkgs.lib.nixosSystem {
            specialArgs = {
              inherit (inputs) agenix;
              inherit inputs;
              inherit (pkgs) lib;
              inherit (config) nodes globals;
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
              # { nix.linux-builder.enable = true; }
              inputs.nix-rosetta-builder.darwinModules.default
              {
                nix-rosetta-builder.onDemand = true;
                nix-rosetta-builder.enable = false;
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
        (mkDarwin "atlas" inputs.nixpkgs-darwin [ ])
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

      deploy.nodes = flip lib.mapAttrs config.nodes (
        name: cfg:
        let
          system = "x86_64-linux";
        in
        {
          hostname = deployCfg.${name}.ip;
          profiles.system = {
            user = "root";
            sshUser = "nixos";
            path = inputs.deploy-rs.lib.${system}.activate.nixos cfg;
          };
          sshOpts = deployCfg.${name}.sshOpts or [ ];
          deploy.remoteBuild = true;
        }
      );
    };
}
