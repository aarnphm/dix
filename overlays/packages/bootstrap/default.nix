{
  writeProgram,
  coreutils,
  git,
  gh,
  rustup,
  lib,
  stdenv,
  makeWrapper,
  bash,
  nix,
}: let
  inherit (lib) getExe;
in
  stdenv.mkDerivation rec {
    pname = "bootstrap";
    version = "0.0.1";
    src =
      writeProgram pname {
        replacements = {
          inherit (stdenv) shell;
          inherit pname;
          FLAKE_URI_BASE = "github:aarnphm/dix";
          gh = getExe gh;
          nix = getExe nix;
          rustup = getExe rustup;
        };
      }
      ./bootstrap.sh;
    strictDeps = true;
    nativeBuildInputs = [makeWrapper];
    buildInputs = [bash nix];
    runtimeInputs = [coreutils git gh nix rustup];
    installPhase = ''
      mkdir -p $out/bin
      ln -s $src/bin/${pname} $out/bin/${pname}
    '';

    postFixup = ''
      wrapProgram $out/bin/${pname} \
        --prefix PATH : "${lib.makeBinPath [rustup bash gh]}"
    '';

    meta = with lib; {
      mainProgram = "${pname}";
      description = "aarnphm/dix bootstrap go brrrrr";
      homepage = "https://github.com/aarnphm/dix";
      license = licenses.asl20;
      maintainers = with maintainers; [aarnphm];
      platforms = platforms.unix;
    };
  }
