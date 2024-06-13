{
  stdenv,
  lib,
  isArm,
  fetchurl,
  unzip,
}: let
  arch =
    if isArm
    then "arm64"
    else "x64";
in
  stdenv.mkDerivation rec {
    name = "Splice";
    version = "5.0.14";
    src = fetchurl {
      url = "https://desktop.splice.com/darwin/stable/${arch}/${name}.app.zip";
      hash = "sha256-UR2U3fCy0ofZ0veSAs0hofR3TwLSVZovOfR34ifds0k=";
    };
    sourceRoot = ".";
    nativeBuildInputs = [unzip];

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications/${name}.app"
      cp -pR * "$out/Applications/${name}.app"

      runHook postInstall
    '';

    meta = with lib; {
      homepage = "https://splice.com/";
      description = "Browse millions of royalty-free one-shots, loops, FX, MIDI, and presets in a sample library deep enough to get lost in. It all starts on Splice.";
      platforms = platforms.darwin;
      maintainers = with maintainers; [aarnphm];
      liecnes = licenses.unlicense;
    };
  }
