{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  fetchNpmDeps,
  aiofiles,
  bcrypt,
  jinja2,
  joserfc,
  nodejs,
  npmHooks,
}:

buildHomeAssistantComponent rec {
  owner = "christaangoossens";
  domain = "auth_oidc";
  version = "1.0.0-rc3"; # use alpha rc version

  src = fetchFromGitHub {
    owner = "christiaangoossens";
    repo = "hass-oidc-auth";
    tag = "v${version}";
    hash = "sha256-TKbzBKDI+pA+aNqnEmhiQZojnD/91fwHT4k939kh8Q0=";
  };

  dependencies = [
    aiofiles
    bcrypt
    jinja2
    joserfc
  ];

  env.npmDeps = fetchNpmDeps {
    name = "${domain}-npm-deps";
    inherit src;
    hash = "sha256-R5i4o2VnaXwgX72r6cBJULxSKadkU22vriMMWoMc5As=";
  };

  nativeBuildInputs = [
    npmHooks.npmConfigHook
    nodejs
  ];

  postBuild = ''
    npm run css
  '';

  meta = {
    changelog = "https://github.com/christiaangoossens/hass-oidc-auth/releases/tag/v${version}";
    description = "OpenID Connect authentication provider for Home Assistant";
    homepage = "https://github.com/christiaangoossens/hass-oidc-auth";
    license = lib.licenses.mit;
  };
}
