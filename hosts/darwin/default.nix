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
    };
  };
}
