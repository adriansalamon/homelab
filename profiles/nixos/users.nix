{ globals, ... }:
{
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = globals.admin-user.pubkeys;
    inherit (globals.admin-user) hashedPassword;

  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  security.sudo.wheelNeedsPassword = false;
}
