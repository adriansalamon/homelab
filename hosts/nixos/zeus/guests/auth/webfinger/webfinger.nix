{ lib, buildGoModule }:
buildGoModule {
  pname = "webfinger-server";
  version = "1.0";

  src = ./package;

  vendorHash = null;

  meta = with lib; {
    description = "Simple WebFinger server for @${globals.domains.alt}";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
