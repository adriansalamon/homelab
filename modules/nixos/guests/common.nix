_guestName: guestCfg:
{ lib, ... }:
let
  inherit (lib) mkForce;
in
{
  node.name = guestCfg.name;

  nix = {
    settings.auto-optimise-store = mkForce false;
    optimise.automatic = mkForce false;
    gc.automatic = mkForce false;
  };
  documentation.enable = mkForce false;

  networking.useNetworkd = true;
}
