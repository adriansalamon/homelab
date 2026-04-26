{
  lib,
  python3,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication (finalAttrs: {
  pname = "oauth-cli-kit";
  version = "0.1.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "pinhua33";
    repo = "oauth-cli-kit";
    tag = "v${finalAttrs.version}";
    hash = "sha256-dJSiR/1fKvYbB8r7pU58vnDeREG/k1YmnhC5qEFtbo4=";
  };

  build-system = [
    python3.pkgs.hatch-vcs
    python3.pkgs.hatchling
  ];

  dependencies = with python3.pkgs; [
    httpx
    platformdirs
  ];

  optional-dependencies = with python3.pkgs; {
    dev = [
      pytest
    ];
  };

  pythonImportsCheck = [
    "oauth_cli_kit"
  ];

  meta = {
    description = "Oauth for coding cli";
    homepage = "https://github.com/pinhua33/oauth-cli-kit";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "oauth-cli-kit";
  };
})
