{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  aiohttp,
  bleak,
  bleak-retry-connector,
  pydantic,
  cryptography,
}:

buildPythonPackage {
  pname = "pyplejd";
  version = "0.20.6";

  src = fetchFromGitHub {
    owner = "thomasloven";
    repo = "pyplejd";
    rev = "ee8cde205b6b7557191e183f6657e489fc3b3149";
    sha256 = "sha256-o9cUvtAUJgMGpqJ1KhTHkNYw1GvZ8zdQhNcmxoJ3k5g=";
  };

  propagatedBuildInputs = [
    aiohttp
    bleak
    bleak-retry-connector
    pydantic
    cryptography
  ];

  doCheck = false;
  pyproject = true;
  build-system = [ setuptools ];

  pythonImportsCheck = [ "pyplejd" ];

  meta = with lib; {
    description = "A python library for communicating with Plejd devices via bluetooth";
    homepage = "https://github.com/thomasloven/pyplejd";
    license = licenses.mit;
  };
}
