{ lib, buildGoModule }:
buildGoModule {
  pname = "nebula-keygen-age";
  version = "0.0.1";

  src = ./src;

  vendorHash = "sha256-G7efQsOI8oJb7iYJZB++McJ+kFeIRZpXZiDcLfugsl4=";

  meta = with lib; {
    description = "Nebula keygen with stdin/stdout instead of files to make it usable with agenix.";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
