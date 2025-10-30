{
  inputs,
  globals,
  ...
}:
{

  system.stateVersion = 5;

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
  };

  system.primaryUser = "asalamon";
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      max-jobs = "auto";
      trusted-users = [
        "root"
        "asalamon"
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
