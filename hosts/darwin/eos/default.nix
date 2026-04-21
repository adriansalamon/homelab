{
  inputs,
  pkgs,
  profiles,
  globals,
  ...
}:
{
  imports = [
    ./paneru.nix
    profiles.darwin
  ];

  globals.nebula.mesh.hosts.eos = {
    id = 4610;
    groups = [ "network-admin" ];

   config.settings.tun.unsafe_routes = [
      {
        route = globals.sites.olympus.vlans.management.cidrv4;
        via = globals.nebula.mesh.hosts.athena.ipv4;
      }
    ];
  };

  # Bootstrap essentials: secrets management, core dev tools
  environment.systemPackages = with pkgs; [
    age-plugin-yubikey
    alejandra
    attic-client
    atuin
    btop
    coreutils
    fzf
    git
    ghostty-bin
    inputs.agenix-rekey.packages."${stdenv.hostPlatform.system}".default
    inputs.deploy-rs.packages."${stdenv.hostPlatform.system}".default
    jq
    lazygit
    nil
    nixd
    nixfmt
    nebula
    nodejs
    # nomad_1_11
    rage
    restic
    tldr
    vault-bin
    vim
    uv
    yq
  ];
  
  homebrew = {
    enable = true;

    casks = [
      "claude-code"
      "firefox"
      "hiddenbar"
      "ukelele"
      "zed"
    ];
	};


  system.stateVersion = 5;
}
