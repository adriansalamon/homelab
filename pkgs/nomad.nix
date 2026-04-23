{
  lib,
  buildGo126Module,
  fetchFromGitHub,
  nixosTests,
  installShellFiles,
}:

let
  generic =
    {
      buildGoModule,
      version,
      hash,
      vendorHash,
      license,
      ...
    }@attrs:
    let
      attrs' = removeAttrs attrs [
        "buildGoModule"
        "version"
        "hash"
        "vendorHash"
        "license"
      ];
    in
    buildGoModule (
      rec {
        pname = "nomad";
        inherit version vendorHash;

        subPackages = [ "." ];

        src = fetchFromGitHub {
          owner = "hashicorp";
          repo = "nomad";
          rev = "v${version}";
          inherit hash;
        };

        nativeBuildInputs = [ installShellFiles ];

        ldflags = [
          "-X github.com/hashicorp/nomad/version.Version=${version}"
          "-X github.com/hashicorp/nomad/version.VersionPrerelease="
          "-X github.com/hashicorp/nomad/version.BuildDate=1970-01-01T00:00:00Z"
        ];

        # ui:
        #  Nomad release commits include the compiled version of the UI, but the file
        #  is only included if we build with the ui tag.
        tags = [ "ui" ];

        postInstall = ''
          echo "complete -C $out/bin/nomad nomad" > nomad.bash
          installShellCompletion nomad.bash
        '';

        meta = {
          homepage = "https://developer.hashicorp.com/nomad";
          description = "Distributed, Highly Available, Datacenter-Aware Scheduler";
          mainProgram = "nomad";
          inherit license;
        };
      }
      // attrs'
    );
in
generic {
  buildGoModule = buildGo126Module;
  version = "2.0.0";
  hash = "sha256-5rCAcOXWQ6g2iK1d5wy/a/DZQC2xwwdpI1SscDX98C8=";
  vendorHash = "sha256-3/H7QgVOHtaUs6BOF7ATVgrA0cfNBbm940Axrvq2bKU=";
  license = lib.licenses.bsl11;
  passthru.tests.nomad = nixosTests.nomad;
  preCheck = ''
    export PATH="$PATH:$NIX_BUILD_TOP/go/bin"
  '';
}
