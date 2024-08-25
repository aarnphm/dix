{
  lib,
  stdenv,
  neovim,
  neovide,
  writeProgram,
}:
stdenv.mkDerivation rec {
  pname = "gvim";
  version = "0.0.1";
  name = pname;

  strictDeps = true;
  buildInputs = [neovim neovide];

  unpackPhase = "true";

  src =
    writeProgram "gvim"
    {
      inherit (stdenv) shell;
      nvim = lib.getExe neovim;
      neovide = lib.getExe neovide;
    }
    ./gvim.sh;

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
