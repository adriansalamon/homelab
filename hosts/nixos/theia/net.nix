_: {
  # Simple network configuration for desktop
  # NetworkManager is already enabled in the desktop profile
  # This provides a simple GUI for managing network connections

  networking.hostName = "theia";

  # Firewall configuration for desktop
  networking.nftables.firewall = {
    enable = true;
    zones.untrusted.interfaces = [
      "e*"
      "w*"
    ]; # All ethernet and wifi interfaces
  };
}
