{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "nixos-auto-updater";
  version = "0.1.0";

  src = ./src;

  vendorHash = "sha256-YCUm/Ndq1oAm3xIG16xeuJUgYbIUpCDPGMMSV0Symgw=";

  meta = with lib; {
    description = "Automatically update NixOS systems with Consul coordination";
    homepage = "https://github.com/asalamon/homelab";
    license = licenses.mit;
    mainProgram = "nixos-auto-updater";
  };
}
