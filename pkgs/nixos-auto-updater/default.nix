{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "nixos-auto-updater";
  version = "0.1.0";

  src = ./src;

  vendorHash = "sha256-r/L0KoA6sk5m4Z3q4UXOnbfGi/PvLDjOu5sWjPhOr5s=";

  meta = with lib; {
    description = "Automatically update NixOS systems with Consul coordination";
    homepage = "https://github.com/asalamon/homelab";
    license = licenses.mit;
    mainProgram = "nixos-auto-updater";
  };
}
