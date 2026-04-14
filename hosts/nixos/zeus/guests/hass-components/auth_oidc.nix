{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  aiofiles,
  bcrypt,
  jinja2,
  joserfc,
}:

buildHomeAssistantComponent rec {
  owner = "christaangoossens";
  domain = "auth_oidc";
  version = "1.0.0-rc2"; # use alpha rc version

  src = fetchFromGitHub {
    owner = "christiaangoossens";
    repo = "hass-oidc-auth";
    tag = "v${version}";
    hash = "sha256-HnmMPz5eQoIOQ/QOLrf00hmH0x0cJhXDOgXUQ76zUTE=";
  };

  dependencies = [
    aiofiles
    bcrypt
    jinja2
    joserfc
  ];

  meta = {
    changelog = "https://github.com/christiaangoossens/hass-oidc-auth/releases/tag/v${version}";
    description = "OpenID Connect authentication provider for Home Assistant";
    homepage = "https://github.com/christiaangoossens/hass-oidc-auth";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ hexa ];
  };
}
