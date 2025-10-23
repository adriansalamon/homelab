{ ... }:
{
  nix = {
    settings = {
      trusted-users = [
        "nixos"
        "root"
        "@wheel"
      ];

      experimental-features = [
        "nix-command"
        "flakes"
      ];

      auto-optimise-store = true;

      substituters = [
        "https://nix-cache.local.salamon.xyz/homelab"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "homelab:1U/4nSASmrwaLvlRbX3wGtDj6q6dPSQTeCbjlqjQ6Ao="
      ];
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}
