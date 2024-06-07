self: super:
let
  xcrunHost = super.runCommand "xcrunHost" { } ''
    mkdir -p $out/bin
    ln -s /usr/bin/xcrun $out/bin
  '';
in
{
  bitwarden-cli = super.buildNpmPackage {
    name = with import ../lib/versions.nix; "bitwarden-cli-${flakeVersion super.dix.bitwarden-cli}";
    src = super.dix.bitwarden-cli;
    nodejs = super.nodejs_20;

    env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

    npmDepsHash = "sha256-fjYez3nSDsG5kYtrun3CkDCz1GNAjNlwPzEL+/9qQRU=";

    nativeBuildInputs = [
      super.python3
    ] ++ super.lib.optionals super.stdenv.isDarwin [
      super.darwin.cctools
      xcrunHost
    ];

    makeCacheWritable = true;

    npmBuildScript = "build:prod";

    npmWorkspace = "apps/cli";

    postInstall = ''
      installShellCompletion --zsh --name _bw <($out/bin/bw completion --shell zsh)
    '';

    meta = {
      mainProgram = "bw";
    };
  };

  git-forest = super.stdenv.mkDerivation {
    pname = "git-forest";
    version = with import ../lib/versions.nix; "${flakeVersion super.git}";
    src = ./packages;
    buildInputs = [ super.perl ];
    nativeBuildInputs = [ super.makeWrapper ];
    installPhase = ''
      install -Dm755 git-forest.pl $out/bin/git-forest
    '';
    postFixup = ''
      wrapProgram $out/bin/git-forest \
        --prefix PERL5LIB : "${with super.perl538Packages; makePerlPath [ Git Error ]}"
    '';
  };
}
