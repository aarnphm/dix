{ isArm, stdenv, lib, fetchurl, unzip, installShellFiles }:
stdenv.mkDerivation rec {
  pname = "paperspace-cli";
  version = "1.10.1";

  src = fetchurl {
    url = "https://github.com/Paperspace/cli/releases/download/${version}/pspace-${if isArm then "macos-arm" else "linux"}.zip";
    hash = if isArm then "sha256-NX0tKvbWCEG2i43M3/r9tzmSI0t8lfRQ5/CXSZZvMeE=" else "sha256-xC2TEHM9sCyo2eZoFlFaNewqS4iqiUYfZDdR+rf7DUY=";
  };

  buildInputs = [ unzip ];
  phases = [ "unpackPhase" "installPhase" ];
  nativeBuildInputs = [ installShellFiles ];
  sourceRoot = "."; # NOTE: since the zip doesn't have any subdirectory, set to do to make sure unpacker won't fail.
  unpackCmd = ''
    unzip $curSrc pspace
  '';
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mv pspace $out/bin

    runHook postInstall
  '';
  postInstall = ''
    installShellCompletion --zsh --cmd pspace <($out/bin/pspace completion zsh)
  '';

  meta = with lib; {
    mainProgram = "pspace";
    changelog = "https://github.com/Paperspace/cli/releases/tag/${src.rev}";
    description = "The CLI for paperspace";
    homepage = "https://www.paperspace.com/";
    license = licenses.gpl3Only;
    maintainers = with maintainers; [ aarnphm ];
    platforms = platforms.unix;
  };
}

