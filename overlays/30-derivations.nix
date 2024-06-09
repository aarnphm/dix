self: super:
let
  isArm = with import ./helpers.nix; checkArm super;

  dix-packages = with import ../lib/versions.nix; {
    editor = {
      name = "editor";
      src = super.dix.editor-nix;
      version = flakeVersion super.dix.editor-nix;
    };
    emulators = {
      name = "emulators";
      src = super.dix.emulator-nix;
      version = flakeVersion super.dix.emulator-nix;
    };
  };

  mkDerivationKeepSrc = { name, src, version }:
    super.stdenv.mkDerivation {
      inherit name src version;
      buildCommand = ''
        mkdir -p $out
        cp -a $src/. $out
      '';
      meta = { description = name; };
    };
in
{
  dix = super.dix or { } // {
    bitwarden-cli =
      let
        pname = "bitwarden-cli";
        version = "2024.4.1";
      in
      super.buildNpmPackage {
        inherit version pname;

        src = super.fetchFromGitHub {
          owner = "bitwarden";
          repo = "clients";
          rev = "cli-v${version}";
          hash = "sha256-Dz7EActqXd97kNxEaNINj2O6TLZWEgHHg1lOIa2+Lt4=";
        };

        nodejs = super.nodejs_18;

        env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

        nativeBuildInputs = [
          super.python3
        ] ++ super.lib.optionals super.stdenv.isDarwin [
          super.darwin.cctools
          (super.runCommand "xcrunHost" { } ''
            mkdir -p $out/bin
            ln -s /usr/bin/xcrun $out/bin
          '')
        ];

        makeCacheWritable = true;

        npmDepsHash = "sha256-fjYez3nSDsG5kYtrun3CkDCz1GNAjNlwPzEL+/9qQRU=";
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

    git-forest = super.callPackage ./packages/git-forest { };
    zsh-dix = super.callPackage ./packages/zsh-dix { };

  } // super.lib.mapAttrs (name: { src, version, ... }: mkDerivationKeepSrc { inherit name src version; }) dix-packages;
}
