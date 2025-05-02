{
  stdenv,
  lib,
  writeProgram,
  curl,
  jq,
  openssh,
  bitwarden-cli,
  gh,
  bash,
  makeWrapper,
  ...
}:
stdenv.mkDerivation rec {
  pname = "lambda";
  version = "0.0.1";
  src =
    writeProgram pname {
      replacements = with lib; {
        inherit (stdenv) shell;
        curl = getExe curl;
        jq = getExe jq;
        ssh = getExe' openssh "ssh";
        scp = getExe' openssh "scp";
        bw = getExe bitwarden-cli;
        LAMBDA_SETUP_TEMPLATE = ./setup_remote.sh.in;
      };
    }
    ./lambda.sh;
  strictDeps = true;
  nativeBuildInputs = [makeWrapper];
  buildInputs = [bash jq];

  installPhase = ''
    mkdir -p $out/bin
    ln -s $src/bin/${pname} $out/bin/${pname}
  '';

  postFixup = ''
    wrapProgram $out/bin/${pname} \
      --prefix PATH : "${lib.makeBinPath [bitwarden-cli bash jq gh]}"
  '';

  meta = with lib; {
    mainProgram = "${pname}";
    description = "Lambda Cloud ops";
    homepage = "https://github.com/aarnphm/dix";
    license = licenses.asl20;
    maintainers = with maintainers; [aarnphm];
    platforms = platforms.unix;
  };
}
