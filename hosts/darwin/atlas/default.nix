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
    age-plugin-yubikey
    alejandra
    attic-client
    atuin
    backrest
    btop
    cook-cli
    coreutils
    fzf
    git
    git-agecrypt
    gleam
    inputs.agenix-rekey.packages."${system}".default
    inputs.deploy-rs.packages."${system}".default
    iperf3
    lazygit
    nebula
    nebula
    nil
    nixd
    nixfmt-rfc-style
    nodejs
    nomad
    rage
    restic
    tldr
    typst
    vim
    yubikey-personalization
  ];

  launchd.user.agents.backrest = {
    serviceConfig.ProgramArguments = [ "${pkgs.backrest}/bin/backrest" ];
    serviceConfig.KeepAlive = true;
  };

  launchd.user.agents.nebula = {
    serviceConfig.ProgramArguments = [
      "${pkgs.nebula}/bin/nebula"
      "-config"
      "/etc/nebula/config.yml"
    ];
    serviceConfig.KeepAlive = true;
  };

  system.stateVersion = 5;
}
