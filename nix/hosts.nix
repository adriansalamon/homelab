{ inputs, ... }:

{

  imports = [
    inputs.home-manager.flakeModules.home-manager
  ];

  flake =
    { config, lib, ... }:
    let
      inherit (lib)
        concatMapAttrs
        mapAttrs'
        flip
        nameValuePair
        ;

      mkRpi =
        name: hostConfig:
        let
          system = "aarch64-linux";
          pkgs = config.pkgs.${system};
          profiles = pkgs.lib.rakeLeaves ../profiles;
        in
        {
          nixosConfigurations.${name} = inputs.nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit (inputs) agenix;
              inherit inputs;
              inherit (pkgs) lib;
              inherit (config) nodes globals;
              inherit profiles;
              nomadCfg = config.nomadConfigurations.homelab;
            };
            modules = [
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
              inherit inputs profiles;
              inherit (pkgs) lib;
              inherit (config) nodes globals;
              nomadCfg = config.nomadConfigurations.homelab;
            };
            modules = [
              ../modules/nixos-host
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
          profiles = pkgs.lib.rakeLeaves ../profiles;
        in
        {
          darwinConfigurations.${name} = inputs.nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            specialArgs = {
              inherit inputs profiles;
              inherit (inputs) agenix;
              inherit (pkgs) lib;
              inherit (config) nodes globals;
            };
            modules = [
              ../hosts/darwin/${name}
              {
                node = {
                  name = name;
                  secretsDir = ../hosts/darwin/${name}/secrets;
                };

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
        (mkHost "theia" { })
        (mkDarwin "atlas" inputs.nixpkgs [ ])
        (mkRpi "callisto" { })
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

      nodes = config.nixosConfigurations // config.guestConfigs // config.darwinConfigurations;

      deploy.nodes =
        flip lib.mapAttrs
          (lib.filterAttrs (n: cfg: cfg.config.node.dummy == false) config.nixosConfigurations)
          (
            name: cfg:
            let
              system = cfg.config.nixpkgs.hostPlatform.system;
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
