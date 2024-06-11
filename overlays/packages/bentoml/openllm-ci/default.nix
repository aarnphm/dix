{ stdenv, lib, writeProgram, bash, coreutils, gh, git, makeWrapper }:
stdenv.mkDerivation rec  {
  pname = "openllm-ci";
  version = "0.0.1";

  src = writeProgram pname
    {
      inherit (stdenv) shell;
      inherit coreutils pname;
      gh = lib.getExe gh;
      git = lib.getExe git;
    }
    ./ci.sh;

  strictDeps = true;
  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ bash coreutils ];
  installPhase = ''
    mkdir -p $out/bin
    ln -s $src/bin/${pname} $out/bin/run-tests
  '';

  postFixup = ''
    wrapProgram $out/bin/run-tests \
      --prefix PATH : "${lib.makeBinPath [ gh git coreutils bash ]}"
  '';

  meta = {
    mainProgram = "run-tests";
    description = "OpenLLM CI system.";
    homepage = "https://github.com/bentoml/OpenLLM";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ aarnphm ];
    platforms = lib.platforms.unix;
  };
}
