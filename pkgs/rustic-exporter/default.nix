{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "rustic-exporter";
  version = "0.1.0-rc.9";

  src = fetchFromGitHub {
    owner = "timtorChen";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-jUAHXZsirU1+9H1IN0y0ds12aShrDn12fuPQOHzE2+0=";
  };

  cargoHash = "sha256-L3TE2TS35ZcKcZZ/RD/PjKpoEk8uap8xQGe8HUOIf+U=";

  meta = with lib; {
    description = "Prometheus exporter for restic/rustic repo stats.";
    license = licenses.mit;
    platforms = platforms.all;
    mainProgram = "rustic-exporter";
  };
}
