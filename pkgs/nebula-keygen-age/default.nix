{ lib, buildGoModule }:
buildGoModule {
  pname = "nebula-keygen-age";
  version = "0.0.1";

  src = ./src;

  vendorHash = "sha256-OIPuqVSJHs9pfJM9dIyuVizhLBymGT54pdpsyDZ2jRQ=";

  meta = with lib; {
    description = "Nebula keygen with stdin/stdout instead of files to make it usable with agenix.";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
