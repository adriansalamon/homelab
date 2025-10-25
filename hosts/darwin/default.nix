{
  inputs,
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

  nix = {
    settings = {
      max-jobs = "auto";
      trusted-users = [
        "root"
        "asalamon"
      ];
      experimental-features = "nix-command flakes";

      substituters = [
        # "https://nix-cache.local.salamon.xyz/homelab"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "homelab:1U/4nSASmrwaLvlRbX3wGtDj6q6dPSQTeCbjlqjQ6Ao="
      ];
    };
  };
}
