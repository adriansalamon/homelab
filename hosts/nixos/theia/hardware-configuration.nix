{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "nvidia" ];
  boot.extraModulePackages = [ config.boot.kernelPackages.nvidia_x11 ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # NVIDIA GPU configuration

  # Enable the NVIDIA proprietary driver
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    # Power management (helps with suspend/resume)
    powerManagement.enable = true;
    powerManagement.finegrained = false;

    # Use the open source kernel module (for Turing and newer GPUs)
    open = true;
  };

  # Additional packages for GPU monitoring/management
  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
    cudaPackages.cudatoolkit
  ];
}
