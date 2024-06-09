{ lib
, stdenv
, darwin
, buildPackages
, fetchNpmDeps
, cargo
, glib
, libsecret
, fetchFromGitHub
, jq
, moreutils
, napi-rs-cli
, nodejs_18
, patchutils_0_4_2
, python3
, runCommand
, rustc
, rustPlatform
}:
let
  nodejs = nodejs_18;

  pname = "Bitwarden";
  version = "2024.5.0";
  description = "A secure and free password manager for all of your devices";
  name = "${pname}-${version}";

  npmHooks = buildPackages.npmHooks.override {
    inherit nodejs;
  };
in
stdenv.mkDerivation rec {
  inherit pname version name;

  src = fetchFromGitHub {
    owner = "bitwarden";
    repo = "clients";
    rev = "desktop-v${version}";
    hash = "sha256-ozR46snGD5yl98FslmnTeQmd2on/0bQPEnqJ0t8wx70=";
  };

  patches = [
    ./electron-builder-package-lock.patch
  ];

  # The nested package-lock.json from upstream is out-of-date, so copy the
  # lock metadata from the root package-lock.json.
  postPatch = ''
    cat {,apps/desktop/src/}package-lock.json \
      | ${lib.getExe jq} -s '
        .[1].packages."".dependencies.argon2 = .[0].packages."".dependencies.argon2
          | .[0].packages."" = .[1].packages.""
          | .[1].packages = .[0].packages
          | .[1]
        ' \
      | ${moreutils}/bin/sponge apps/desktop/src/package-lock.json
  '';

  npmDeps = fetchNpmDeps {
    forceGitDeps = false;
    forceEmptyCache = false;
    src = src;
    patches = patches;
    postPatch = postPatch;
    name = "${name}-npm-deps";
    hash = "sha256-gprJGOE/uSSM3NHpcbelB7sueObEl4o522WRHIRFmwo=";
  };

  makeCacheWritable = true;
  npmWorkspace = "apps/desktop";
  npmBuildScript = "build";

  cargoDeps = rustPlatform.fetchCargoTarball {
    name = "${pname}-${version}";
    inherit src;
    patches = map
      (patch: runCommand
        (builtins.baseNameOf patch)
        { nativeBuildInputs = [ patchutils_0_4_2 ]; }
        ''
          < ${patch} filterdiff -p1 --include=${lib.escapeShellArg cargoRoot}'/*' > $out
        ''
      )
      patches;
    patchFlags = [ "-p4" ];
    sourceRoot = "${src.name}/${cargoRoot}";
    hash = "sha256-G+7FFgn0I4vq04+JF6w96i8IqqzQ5/3bx8uZkOroR+0=";
  };
  cargoRoot = "apps/desktop/desktop_native";

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

  nativeBuildInputs = [
    nodejs
    npmHooks.npmConfigHook
    npmHooks.npmBuildHook
    npmHooks.npmInstallHook
    nodejs.python
    cargo
    jq
    moreutils
    napi-rs-cli
    python3
    rustc
    rustPlatform.cargoCheckHook
    rustPlatform.cargoSetupHook
    darwin.cctools
    (runCommand "impureHostArm" { } ''
      mkdir -p $out/bin
      ln -s /usr/bin/xcrun $out/bin
    '')
  ];

  buildInputs = (with darwin.apple_sdk.frameworks; [ CoreFoundation Security AppKit CoreServices SystemConfiguration ]) ++ [ nodejs glib libsecret ];

  strictDeps = true;
  dontStrip = true;

  npmBuildFlags = [ "--" "--target" "aarch64-apple-darwin" ];

  postBuild = ''
    pushd apps/desktop

    npm exec electron-builder -- --mac --arm64 -p never --dir 2>/dev/null || true

    popd
  '';

  doCheck = true;

  checkFlags = [
    "--skip=password::password::tests::test"
    "--skip=clipboard::tests::test_write_read"
  ];

  checkPhase = ''
    runHook preCheck

    pushd ${cargoRoot}
    export HOME=$(mktemp -d)
    export -f cargoCheckHook runHook _eval _callImplicitHook
    export cargoCheckType=release
    bash -e -c cargoCheckHook
    popd

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir $out

    pushd apps/desktop/dist/mac-arm64
    mkdir -p "$out/Applications"
    cp -pR * "$out/Applications"

    popd

    runHook postInstall
  '';

  meta = {
    changelog = "https://github.com/bitwarden/clients/releases/tag/${src.rev}";
    inherit description;
    homepage = "https://bitwarden.com";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.darwin;
    mainProgram = "bitwarden";
  };
}
