{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  aiofiles,
  bcrypt,
  jinja2,
  python-jose,
}:

buildHomeAssistantComponent rec {
  owner = "christaangoossens";
  domain = "auth_oidc";
  version = "0.7.0-alpha-rc3"; # use alpha rc version

  src = fetchFromGitHub {
    owner = "christiaangoossens";
    repo = "hass-oidc-auth";
    tag = "v${version}";
    hash = "sha256-aflyMZ5v/9aOp5z3HgiU+vaYv8cTXaf+CCK88/KqLgo=";
  };

  dependencies = [
    aiofiles
    bcrypt
    jinja2
    python-jose
  ];

  meta = {
    changelog = "https://github.com/christiaangoossens/hass-oidc-auth/releases/tag/v${version}";
    description = "OpenID Connect authentication provider for Home Assistant";
    homepage = "https://github.com/christiaangoossens/hass-oidc-auth";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ hexa ];
  };
}
