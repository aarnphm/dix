{
  lib,
  stdenv,
  neovim,
  neovide,
  runCommand,
  substituteInPlace,
  bash,
  netcat,
}:
stdenv.mkDerivation rec {
  pname = "gvim";
  version = "0.0.1";
  name = pname;

  strictDeps = true;
  buildInputs = [neovim neovide bash netcat];

  unpackPhase = "true";

  scriptContent = ''
    #!${lib.getExe bash}
    set -e
    set -o pipefail

    file_path="$1"
    port=6666

    if [ -n "$file_path" ]; then
      @@nvim@@ --headless --listen 127.0.0.1:$port "$file_path" &
    else
      @@nvim@@ --headless --listen 127.0.0.1:$port &
    fi

    # Wait for nvim to start and listen on the port
    while ! @@nc@@ -z 127.0.0.1 $port; do
      sleep 0.1
    done

    # Spawn neovide and connect to the nvim server
    @@neovide@@ --server=127.0.0.1:$port
  '';

  gvimScript = runCommand pname
    {
      nativeBuildInputs = [substituteInPlace];
      meta.mainProgram = pname;
    }
    '''
      mkdir -p $out/bin
      echo "${scriptContent}" > $out/bin/${pname}
      chmod +x $out/bin/${pname}
      substituteInPlace $out/bin/${pname} \
        --replace '@@nvim@@' '${lib.getExe neovim}' \
        --replace '@@neovide@@' '${lib.getExe neovide}' \
        --replace '@@nc@@' '${lib.getExe netcat}'
    ''';

  src = gvimScript;

  installPhase = ''
    mkdir -p $out/bin
    ln -s $src/bin/gvim $out/bin/gvim
  '';

  meta = {
    mainProgram = "gvim";
    description = "neovim but GUI";
    homepage = "https://github.com/aarnphm/dix";
    maintainers = with lib.maintainers; [aarnphm];
    platforms = lib.platforms.unix;
  };
}
