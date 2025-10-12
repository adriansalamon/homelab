{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "rustic-exporter";
  version = "78a132887e820922660c726b1299272495eeb11e";

  src = fetchFromGitHub {
    owner = "adriansalamon";
    repo = pname;
    rev = version;
    hash = "sha256-OYFcahH0RJ4epN6/9KuJsKeQnoi1A76zSaoAj9kL+ik=";
  };

  cargoHash = "sha256-Fr7fhfMBt8ouKh8WcjHrrM1IAFBZ6fzaAs7Z0POAr8c=";

  meta = with lib; {
    description = "Prometheus exporter for restic/rustic repo stats.";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "rustic-exporter";
  };
}
