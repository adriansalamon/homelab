{
  profiles,
  inputs,
  globals,
  ...
}:
{
  # Desktop workstation
  node.site = "olympus";
  node.ci = false;

  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
    ./net.nix
    inputs.home-manager.nixosModules.home-manager
  ]
  ++ (with profiles; [
    nixos
    impermanence
    zfs
    desktop
  ]);

  # Generate with: head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n'
  # hostId must be exactly 8 hex characters (32 bits)
  networking.hostId = "c2dfa71a";

  # Boot configuration
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 10;
    efi.canTouchEfiVariables = true;
  };
  # Enable NTFS support for accessing Windows partitions
  boot.supportedFilesystems = [ "ntfs" ];

  # Enable home-manager for your user
  home-manager.users.asalamon = {
    imports = [
      {
        home.stateVersion = "26.05";
      }
      inputs.agenix.homeManagerModules.default
      inputs.nvf.homeManagerModules.default
      ../../../users/asalamon/nixos
    ];
  };

  # Create your user account
  users.users.asalamon = {
    isNormalUser = true;
    description = "Adrian Salamon";
    extraGroups = [
      "wheel" # sudo access
      "networkmanager" # manage network
      "video" # access to video devices
      "audio" # access to audio devices
      "input" # access to input devices
      "disk" # access to disks
    ];

    openssh.authorizedKeys.keys = globals.admin-user.pubkeys;
    inherit (globals.admin-user) hashedPassword;
  };

  system.stateVersion = "26.05";
}
