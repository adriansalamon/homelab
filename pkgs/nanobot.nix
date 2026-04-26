{
  lib,
  python3,
  fetchFromGitHub,
  oauth-cli-kit,
  slackify-markdown-python,
}:

python3.pkgs.buildPythonApplication (finalAttrs: {
  pname = "nanobot";
  version = "0.1.5.post2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "HKUDS";
    repo = "nanobot";
    tag = "v${finalAttrs.version}";
    hash = "sha256-o1tXAQg8ihvcK0jcNPigvfKJaBnGZp8V+2h8R6EzN0g=";
  };

  build-system = [
    python3.pkgs.hatchling
  ];

  dependencies =
    with python3.pkgs;
    [
      anthropic
      chardet
      croniter
      ddgs
      dulwich
      filelock
      httpx
      jinja2
      json-repair
      loguru
      mcp
      msgpack
      openai
      openpyxl
      prompt-toolkit
      pydantic
      pydantic-settings
      pypdf
      python-docx
      python-pptx
      python-socketio
      python-socks
      python-telegram-bot
      pyyaml
      questionary
      readability-lxml
      rich
      slack-sdk
      socksio
      tiktoken
      typer
      websocket-client
      websockets
    ]
    ++ [
      oauth-cli-kit
      slackify-markdown-python
    ];

  optional-dependencies = with python3.pkgs; {
    api = [
      aiohttp
    ];
    dev = [
      aiohttp
      pymupdf
      pytest
      pytest-asyncio
      pytest-cov
      ruff
    ];
    discord = [
      discord-py
    ];
    langsmith = [
      langsmith
    ];
    matrix = [
      matrix-nio
      mistune
      nh3
    ];
    msteams = [
      cryptography
      pyjwt
    ];
    pdf = [
      pymupdf
    ];
    wecom = [
      wecom-aibot-sdk-python
    ];
    weixin = [
      pycryptodome
      qrcode
    ];
  };

  dontCheckRuntimeDeps = true;

  meta = {
    description = "Nanobot: The Ultra-Lightweight Personal AI Agent";
    homepage = "https://github.com/HKUDS/nanobot";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "nanobot";
  };
})
