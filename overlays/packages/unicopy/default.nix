{ stdenv, lib, writeProgram, bash, coreutils, xclip, xsel, gawk, substituteAll, runCommand }:
stdenv.mkDerivation (finalAttrs: {
  pname = "unicopy";
  version = "0.0.1";

  src = writeProgram "copy"
    {
      inherit (stdenv) shell;
      inherit xclip;
      pbcopy =
        if stdenv.isDarwin then
          (lib.getExe (
            runCommand "impureHostDarwinCopy"
              {
                meta = { mainProgram = "pbcopy"; };
              }
              ''
                mkdir -p $out/bin
                ln -s /usr/bin/pbcopy $out/bin
              ''
          )) else "pbcopy";
    }
    ./copy.sh;

  strictDeps = true;
  buildInputs = [ bash coreutils xclip xsel gawk ];

  unpackPhase = "true";

  installPhase = ''
    mkdir -p $out/bin
    ln -s $src/bin/copy $out/bin/copy
  '';

  meta = {
    mainProgram = "copy";
    description = "copy, but universal";
    homepage = "https://github.com/aarnphm/dix";
    maintainers = with lib.maintainers; [ aarnphm ];
    platforms = lib.platforms.unix;
  };
})
