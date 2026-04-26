{
  pkgs,
  lib,
  profiles,
  ...
}:
{
  imports = [
    profiles.storage-users
  ];

  # Add admin user with SSH access
  users.users.adrian = {
    createHome = lib.mkForce true;
    extraGroups = [
      "docker"
    ];
  };

  # Persistence for SSH keys and user data
  environment.persistence."/persist" = {
    directories = [
      "/home/adrian"
    ];
  };

  # Install claude-code and development tools
  environment.systemPackages = with pkgs; [
    # Claude Code
    claude-code-bin
  ];

  # Enable Docker for development
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # Create workspace directory for development
  systemd.tmpfiles.rules = [
    "d /workspace 0700 adrian users -"
  ];

  # Mount workspace as persistent storage
  fileSystems."/workspace" = {
    device = "/persist/workspace";
    fsType = "none";
    options = [ "bind" ];
  };
}
