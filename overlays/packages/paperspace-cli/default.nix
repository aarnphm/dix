{ isArm, stdenv, fetchurl, unzip }:
stdenv.mkDerivation rec {
  pname = "paperspace-cli";
  version = "1.10.1";

  src = fetchurl {
    url = "https://github.com/Paperspace/cli/releases/download/${version}/pspace-${if isArm then "macos-arm" else "linux"}.zip";
    hash = if isArm then "sha256-NX0tKvbWCEG2i43M3/r9tzmSI0t8lfRQ5/CXSZZvMeE=" else "";
  };

  buildInputs = [ unzip ];
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
}

