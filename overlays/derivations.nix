self: super:
let
  xcrunHost = super.runCommand "xcrunHost" { } ''
    mkdir -p $out/bin
    ln -s /usr/bin/xcrun $out/bin
  '';
  isArm = builtins.match "aarch64-.*" super.stdenv.hostPlatform.system != null;
in
{
  bitwarden-cli = super.buildNpmPackage rec {
    pname = "bitwarden-cli";
    version = "2024.4.1";

    src = super.fetchFromGitHub {
      owner = "bitwarden";
      repo = "clients";
      rev = "cli-v${version}";
      hash = "sha256-JBEP4dNGL4rYKl2qNyhB2y/wZunikaGFltGVXLxgMWI=";
    };

    nodejs = super.nodejs_20;

    env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

    npmDepsHash = "sha256-vNudSHIMmF7oXGz+ZymQahyHebs/CBDc6Oy1g0A5nqA=";

    nativeBuildInputs = [
      super.python3
    ] ++ super.lib.optionals super.stdenv.isDarwin [
      super.darwin.cctools
      xcrunHost
    ];

    makeCacheWritable = true;
    npmBuildScript = "build:prod";
    npmWorkspace = "apps/cli";
    npmFlags = [ "--legacy-peer-deps" ];

    postInstall = ''
      installShellCompletion --zsh --name _bw <($out/bin/bw completion --shell zsh)
    '';

    meta = {
      mainProgram = "bw";
    };
  };

  paperspace-cli =
    let
      pname = "paperspace-cli";
      version = "1.10.1";
      target = if isArm then "macos-arm" else "linux";
    in
    super.stdenv.mkDerivation (finalAttrs: {
      inherit pname version;
      src = super.fetchurl {
        url = "https://github.com/Paperspace/cli/releases/download/${version}/pspace-${target}.zip";
        hash = if isArm then "sha256-NX0tKvbWCEG2i43M3/r9tzmSI0t8lfRQ5/CXSZZvMeE=" else "";
      };

      buildInputs = with super; [ unzip ];
      phases = [ "unpackPhase" "installPhase" ];
      sourceRoot = "."; # NOTE: since the zip doesn't have any subdirectory, set to do to make sure unpacker won't fail.
      unpackCmd = ''
        unzip $curSrc pspace
      '';
      installPhase = ''
        mkdir -p $out/bin
        mv pspace $out/bin
      '';
      postInstall = ''
        installShellCompletion --zsh --cmd pspace <($out/bin/pspace completion zsh)
      '';
    });

  editor = super.stdenv.mkDerivation {
    name = with import ../lib/versions.nix; "editor-nix-${flakeVersion super.dix.editor-nix}";
    src = super.dix.editor-nix;
    buildCommand = ''
      mkdir -p $out
      cp -r $src/* $out
    '';
  };

  emulators = super.stdenv.mkDerivation {
    name = with import ../lib/versions.nix; "emulators-${flakeVersion super.dix.emulator-nix}";
    src = super.dix.emulator-nix;
    buildCommand = ''
      mkdir -p $out
      cp -r $src/* $out
    '';
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
