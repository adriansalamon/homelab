{
  inputs,
  pkgs,
  ...
}:
{

  imports = [
    ./yabai.nix
  ];

  environment.systemPackages = with pkgs; [
    coreutils
    git
    vim
    age-plugin-yubikey
    inputs.agenix-rekey.packages."${system}".default
    deploy-rs
    nixd
    nil
    nixfmt-rfc-style
    rage
    yubikey-personalization
    btop
    iperf3
    alejandra
    fzf
    nebula
    atuin
    tldr
    nebula
    git-agecrypt
    typst
  ];

  system.stateVersion = 5;
}
