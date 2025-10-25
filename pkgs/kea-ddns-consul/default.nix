{ lib, buildGoModule }:
buildGoModule {
  pname = "kea-ddns-consul";
  version = "0.0.1";

  src = ./src;

  # no dependencies
  vendorHash = null;

  meta = with lib; {
    description = "KEA DDNS to Consul";
    license = licenses.mit;
    mainProgram = "kea-ddns-consul";
    platforms = platforms.all;
  };
}
