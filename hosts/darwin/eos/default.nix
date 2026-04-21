{
  inputs,
  pkgs,
  profiles,
  ...
}:
{
  imports = [
    profiles.darwin
  ];

  # Bootstrap essentials: secrets management, core dev tools
  environment.systemPackages = with pkgs; [
    age-plugin-yubikey
    alejandra
    atuin
    btop
    fzf
    git
    git-agecrypt
    inputs.agenix-rekey.packages."${stdenv.hostPlatform.system}".default
    lazygit
    nil
    nixd
    nixfmt
    rage
    vault-bin
    vim
  ];

  system.stateVersion = 5;
}
