{
  buildHomeAssistantComponent,
  fetchFromGitHub,
}:

buildHomeAssistantComponent rec {
  owner = "mjcumming";
  domain = "wiim";
  version = "0.2.18";

  src = fetchFromGitHub {
    inherit owner;
    repo = domain;
    tag = "v${version}";
    hash = "sha256-9Z7xoOPvQh3aGVi6TPO82cBQUhqHTxf4gW5Nfo7Wg0k=";
  };

  meta = {
    changelog = "https://github.com/mjcumming/wiim/releases/tag/v${version}";
    description = "WiiM Audio Integration for Home Assistant";
    homepage = "https://github.com/mjcumming/wiim";
  };
}
