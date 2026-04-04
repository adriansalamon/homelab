{
  inputs,
  globals,
  ...
}:
{

  system = {
    stateVersion = 5;
    primaryUser = "asalamon";
  };

  networking.hostName = "atlas";

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
  };

  age.rekey = {
    inherit (inputs.self.secretsConfig) masterIdentities;

    storageMode = "local";
    hostPubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOB8IHga1YmPPxMGRzmcX08aAf34Szmt9HLsohZd/CBW";
    generatedSecretsDir = inputs.self.outPath + "/secrets/generated/atlas";
    localStorageDir = inputs.self.outPath + "/secrets/rekeyed/atlas";
  };

  nixpkgs.config.allowUnfree = true;

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
