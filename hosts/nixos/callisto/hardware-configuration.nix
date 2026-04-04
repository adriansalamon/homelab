{
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  # Raspberry Pi 3B+ specific configuration
  boot = {
    # Use the extlinux boot loader (works well with Raspberry Pi)
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

    initrd.availableKernelModules = [
      "usbhid"
      "usb_storage"
    ];

    kernelModules = [ ];

    # Enable console output
    kernelParams = [
      "console=ttyS1,115200n8"
      "console=tty0"
    ];
  };

  # Filesystem configuration for SD card
  # Using persistent root for simplicity with Raspberry Pi SD images
  # The SD image builder populates /nix directly, so we can't use tmpfs root + bind mounts
  # environment.persistence will still work - it will create the /persist and /state structure
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    # Use noatime to reduce SD card wear
    options = [ "noatime" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
  };

  # On Raspberry Pi with persistent root, /persist and /state are just directories on root
  # They don't need separate filesystem declarations, but the impermanence module requires
  # them to have neededForBoot = true. Since they're on root, this is automatically satisfied.
  # We mark them as bind mounts to themselves to satisfy the module's checks.
  fileSystems."/persist" = lib.mkForce {
    device = "/persist";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };
  fileSystems."/state" = lib.mkForce {
    device = "/state";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };

  swapDevices = [ ];

  # Enable Raspberry Pi hardware support
  hardware = {
    deviceTree.enable = true;
    enableRedistributableFirmware = true;
  };

  networking.useDHCP = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # Power management
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  # Increase boot partition size for SD card image
  sdImage.firmwareSize = 300; # MB
}
