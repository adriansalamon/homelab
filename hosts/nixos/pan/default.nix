{
  config,
  globals,
  profiles,
  lib,
  ...
}:
let
  site = globals.sites.${config.node.site};
in
{
  # dommy router host for now
  node.site = "arcadia";
  node.dummy = true;

  # dommy key
  age.rekey.hostPubkey = lib.mkForce "age1qyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqszqgpqyqs3290gq";

  imports = with profiles; [
    common
    router.nebula
  ];

  globals.nebula.mesh.hosts.${config.node.name} = {
    id = 10;

    routeSubnets = [
      site.vlans.lan.cidrv4
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  system.stateVersion = "24.11";
}
