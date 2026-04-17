{
  buildHomeAssistantComponent,
  fetchFromGitHub,
  pyplejd,
  pydantic,
}:

buildHomeAssistantComponent rec {
  owner = "thomasloven";
  domain = "plejd";
  version = "0.20.6";

  src = fetchFromGitHub {
    inherit owner;
    repo = "hass-plejd";
    tag = "v${version}";
    hash = "sha256-lDDqFYCBsIWX4mICHX2MVVrfkSWiXmu8/G/OfSf4GKk=";
  };

  propagatedBuildInputs = [
    pyplejd
  ];

  dependencies = [
    pydantic
  ];

  meta = {
    changelog = "https://github.com/thomasloven/hass-plejd/releases/tag/v${version}";
    description = "Plejd integration for Home Assistant";
    homepage = "https://github.com/thomasloven/hass-plejd";
  };
}
