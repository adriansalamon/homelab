{ lib, buildGoModule }:
buildGoModule {
  pname = "nebula-keygen-age";
  version = "0.0.1";

  src = ./src;

  vendorHash = "sha256-jgXlROzWOb9zbjpOrpIHIh9NGJQAXN0ofeQY3CEx+Hk=";

  meta = with lib; {
    description = "Nebula keygen with stdin/stdout instead of files to make it usable with agenix.";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
