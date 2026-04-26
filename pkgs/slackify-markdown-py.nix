{
  lib,
  python3,
  fetchFromGitHub,
}:

python3.pkgs.buildPythonApplication (finalAttrs: {
  pname = "slackify-markdown-python";
  version = "0.2.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "thesmallstar";
    repo = "slackify-markdown-python";
    tag = "v${finalAttrs.version}";
    hash = "sha256-16LAnzOPoO/uNAt/NaffDsQhOX6U5d8spTsUNBzcehA=";
  };

  build-system = [
    python3.pkgs.setuptools
    python3.pkgs.wheel
  ];

  dependencies = with python3.pkgs; [
    markdown-it-py
  ];

  pythonImportsCheck = [
    "slackify_markdown"
  ];

  meta = {
    description = "Convert Markdown to Slack compatible markdown";
    homepage = "https://github.com/thesmallstar/slackify-markdown-python";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "slackify-markdown-python";
  };
})
