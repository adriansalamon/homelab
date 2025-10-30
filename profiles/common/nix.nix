{
  config,
  globals,
  inputs,
  ...
}:
{
  # Contents:
  # machine nix-cache.<domain>
  # password <attic token>
  age.secrets.nix-cache-netrc = {
    rekeyFile = inputs.self.outPath + "/secrets/nix-cache.netrc.age";
  };

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
        "https://nix-cache.local.${globals.domains.main}/homelab"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "homelab:leKffLkOCSfX8pPGaQltduLxJNNVmG5oGPt6w3fH4t0="
      ];

      netrc-file = config.age.secrets.nix-cache-netrc.path;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
}
