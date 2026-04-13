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
    { nix.linux-builder.enable = true; }
    #inputs.nix-rosetta-builder.darwinModules.default
    #{
    #  nix-rosetta-builder.onDemand = true;
    #  nix-rosetta-builder.enable = false;
    #}
    inputs.home-manager.darwinModules.home-manager
    ../../modules/common
    ../../modules/darwin
  ]
  ++ lib.collect builtins.isPath (lib.filterAttrs (n: _: n != "default") (lib.rakeLeaves ./.));

  system.primaryUser = "asalamon";

  networking.hostName = config.node.name;

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";

    users.asalamon.imports = [
      inputs.agenix.homeManagerModules.default
      ../../users/asalamon/darwin
    ];
  };

  age.rekey = {
    inherit (inputs.self.secretsConfig) masterIdentities;

    storageMode = "local";
    hostPubkey = config.node.secretsDir + "/host.pub";
    generatedSecretsDir = inputs.self.outPath + "/secrets/generated/${config.node.name}";
    localStorageDir = inputs.self.outPath + "/secrets/rekeyed/${config.node.name}";
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
