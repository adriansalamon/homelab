{
  pkgs,
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
}:

buildPythonPackage {
  pname = "pyplejd";
  version = "0.14.7";

  src = fetchFromGitHub {
    owner = "thomasloven";
    repo = "pyplejd";
    rev = "e2b4e40c1dbb09bccb6c5e573f57b8309e48ab5c";
    sha256 = "sha256-B9jHENiv60xCgPpKcV1ezj2n1bsSegCxtZfd3/cBwvo=";
  };

  propagatedBuildInputs = with pkgs.python3Packages; [
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
