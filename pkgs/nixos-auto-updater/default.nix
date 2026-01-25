{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "nixos-auto-updater";
  version = "0.1.0";

  src = ./src;

  vendorHash = "sha256-q8R1ZwZ8/j5C6acuo5Z+QsNecpQf5WASmG+CiniBSk0=";

  meta = with lib; {
    description = "Automatically update NixOS systems with Consul coordination";
    homepage = "https://github.com/asalamon/homelab";
    license = licenses.mit;
    mainProgram = "nixos-auto-updater";
  };
}
