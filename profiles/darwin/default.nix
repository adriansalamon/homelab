{
  config,
  globals,
  inputs,
  lib,
  ...
}:
{
  imports = [
    inputs.agenix.darwinModules.default
    inputs.agenix-rekey.darwinModules.default
    #inputs.nix-rosetta-builder.darwinModules.default
    #{
    #  nix-rosetta-builder.onDemand = true;
    #  nix-rosetta-builder.enable = false;
    #}
    inputs.home-manager.darwinModules.home-manager
    ../../modules/common
    ../../modules/darwin
    ../common
  ]
  ++ lib.collect builtins.isPath (lib.filterAttrs (n: _: n != "default") (lib.rakeLeaves ./.));

  system.primaryUser = "asalamon";

  networking.hostName = config.node.name;

  home-manager = {
    extraSpecialArgs = { inherit inputs globals; };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";

    users.asalamon.imports = [
      inputs.agenix.homeManagerModules.default
      inputs.nvf.homeManagerModules.default
      ../../users/asalamon/darwin
    ];
  };

  nixpkgs.config = {
    allowUnfree = true;
    # supress warning
    allowDeprecatedx86_64Darwin = true;
  };

  nix = {
    linux-builder.enable = true;

    settings = {
      max-jobs = "auto";
      trusted-users = [
        "root"
        "asalamon"
        "@admin"
      ];
      experimental-features = "nix-command flakes";

      substituters = [
        "https://nix-cache.${globals.domains.main}/homelab"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "homelab:leKffLkOCSfX8pPGaQltduLxJNNVmG5oGPt6w3fH4t0="
      ];
    };
  };
}
