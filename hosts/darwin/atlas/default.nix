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
    inputs.deploy-rs.packages."${system}".default
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
    backrest
    restic
    cook-cli
    nodejs
    lazygit
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
