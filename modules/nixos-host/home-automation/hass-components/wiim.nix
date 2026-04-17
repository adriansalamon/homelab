{
  buildHomeAssistantComponent,
  fetchFromGitHub,
  pywiim,
}:

buildHomeAssistantComponent rec {
  owner = "mjcumming";
  domain = "wiim";
  version = "1.0.74";

  src = fetchFromGitHub {
    inherit owner;
    repo = domain;
    tag = "v${version}";
    hash = "sha256-HHseOX/FJzSnBLlwmXUFtWqUcebutpte0sZLfx62U70=";
  };

  propagatedBuildInputs = [
    pywiim
  ];

  meta = {
    changelog = "https://github.com/mjcumming/wiim/releases/tag/v${version}";
    description = "WiiM Audio Integration for Home Assistant";
    homepage = "https://github.com/mjcumming/wiim";
  };
}
