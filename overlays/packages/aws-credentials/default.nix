{ stdenv, jq, lib, writeProgram, dix, makeWrapper, bash }:
let
  inherit (lib) getExe;
in
stdenv.mkDerivation rec {
  pname = "aws-credentials";
  version = "0.0.1";

  src = writeProgram pname
    {
      inherit (stdenv) shell;
      inherit pname;
      bw = getExe dix.bitwarden-cli;
      jq = getExe jq;
    } ./secrets.sh;
  strictDeps = true;
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ bash jq ];
  installPhase = ''
    mkdir -p $out/bin
    ln -s $src/bin/${pname} $out/bin/${pname}
  '';

  postFixup = ''
    wrapProgram $out/bin/${pname} \
      --prefix PATH : "${lib.makeBinPath [ dix.bitwarden-cli bash jq ]}"
  '';

  meta = with lib; {
    mainProgram = "${pname}";
    description = "AWS credentials retriever";
    homepage = "https://github.com/aarnphm/dix";
    license = licenses.asl20;
    maintainers = with maintainers; [ aarnphm ];
    platforms = platforms.unix;
  };
}

