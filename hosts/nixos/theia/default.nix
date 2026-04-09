{ profiles, inputs, ... }:
{
  # Desktop workstation
  node.site = "olympus";

  imports = [
    ./disk-config.nix
    ./hardware-configuration.nix
    ./net.nix
    inputs.home-manager.nixosModules.home-manager
  ]
  ++ (with profiles; [
    common
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

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICOfx4SWN/ygsiUkWWWRCFcTz/SBBRO0qKirHiYuvr3x"
    ];
    hashedPassword = "$6$g8JRA4PgwPnXQmy8$X8I0cWTgUIDFEYCJnt.09v3Ep7s69Wauo8kytJA0ik8scB9Owg/7.scFcvVMyYr8gCb0GWbSjPFtVwWXthvpC.";
  };

  system.stateVersion = "26.05";
}
