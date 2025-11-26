{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "nixos-auto-updater";
  version = "0.1.0";

  src = ./src;

  vendorHash = "sha256-q0R7ceW5ysNRrqMu/HD1Zzm+BSgegP9JZNzY6fBpsVo=";

  meta = with lib; {
    description = "Automatically update NixOS systems with Consul coordination";
    homepage = "https://github.com/asalamon/homelab";
    license = licenses.mit;
    mainProgram = "nixos-auto-updater";
  };
}
