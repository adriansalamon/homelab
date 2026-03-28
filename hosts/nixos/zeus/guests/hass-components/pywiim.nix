{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  aiohttp,
  pydantic,
  async-upnp-client,
  m3u8,
  mutagen,
}:

buildPythonPackage rec {
  pname = "pywiim";
  version = "2.1.97";

  src = fetchFromGitHub {
    owner = "mjcumming";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-DoYspG0St47SAaYA8v33nc2h0YDrgmRC6+bXbf4Rpt4=";
  };

  propagatedBuildInputs = [
    aiohttp
    pydantic
    async-upnp-client
    m3u8
    mutagen
  ];

  doCheck = false;
  pyproject = true;
  build-system = [ setuptools ];

  pythonImportsCheck = [ "pywiim" ];

  meta = with lib; {
    description = "Python library for WiiM and LinkPlay device control with command-line tools for discovery, diagnostics, and monitoring.";
    homepage = "https://github.com/mjcumming/pywiim";
    license = licenses.mit;
  };
}
