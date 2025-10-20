{ ... }:
{
  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICOfx4SWN/ygsiUkWWWRCFcTz/SBBRO0qKirHiYuvr3x"
    ];
    hashedPassword = "$6$g8JRA4PgwPnXQmy8$X8I0cWTgUIDFEYCJnt.09v3Ep7s69Wauo8kytJA0ik8scB9Owg/7.scFcvVMyYr8gCb0GWbSjPFtVwWXthvpC.";
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    settings.PermitRootLogin = "no";
  };

  security.sudo.wheelNeedsPassword = false;
}
