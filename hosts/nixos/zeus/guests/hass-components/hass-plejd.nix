{
  buildHomeAssistantComponent,
  fetchFromGitHub,
  pyplejd,
}:

buildHomeAssistantComponent rec {
  owner = "thomasloven";
  domain = "plejd";
  version = "0.14.7";

  src = fetchFromGitHub {
    inherit owner;
    repo = domain;
    tag = "v${version}";
    hash = "sha256-nEwD48q2cOHHP8+4Rb83uyr8JbZXOa4Tvm9e0QbMllQ=";
  };

  propagatedBuildInputs = [
    pyplejd
  ];

  meta = {
    changelog = "https://github.com/thomasloven/hass-plejd/releases/tag/v${version}";
    description = "Plejd integration for Home Assistant";
    homepage = "https://github.com/thomasloven/hass-plejd";
  };
}
