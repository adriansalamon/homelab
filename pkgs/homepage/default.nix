{
  stdenv,
  nodejs,
  pnpm,
  fetchFromGitea,
  makeWrapper,
  ...
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "homepage";
  version = "0.1.0";

  src = fetchFromGitea {
    domain = "forgejo.salamon.xyz";
    owner = "adrian";
    repo = "homepage";
    rev = "5649ec2c6fcf3acdf05742833f3651ed0f804e7e";
    hash = "sha256-Ui3Zm5odfo/7tywR5aOH15Frld5OJjXTuy9yuteyEb8=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm.configHook
    makeWrapper
  ];

  buildPhase = ''
    runHook preBuild
    pnpm run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/homepage

    cp -r build $out/lib/homepage/
    cp -r node_modules $out/lib/homepage/
    cp package.json $out/lib/homepage/

    makeWrapper ${nodejs}/bin/node $out/bin/homepage \
      --add-flags "$out/lib/homepage/build/index.js"

    runHook postInstall
  '';

  dontStrip = true;
  dontPatchELF = true;

  pnpmDeps = pnpm.fetchDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 2;
    hash = "sha256-sjNMVv2hfPhl5AWnD32VfT+07Dhsk9dCypN2zHpb3F8=";
  };

  meta = {
    description = "Homepage application";
    mainProgram = "homepage";
  };
})
