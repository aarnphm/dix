{ stdenv, lib, }:
stdenv.mkDerivation {
  name = "zsh-dix";
  src = ./.;
  stricDeps = true;
  installPhase = ''
    mkdir -p $out/share/zsh
    cp *.zsh $out/share/zsh
    cp -r site-functions/ $out/share/zsh
  '';

  meta = {
    description = "Aaron's zsh configuration";
    homepage = "https://github.com/aarnphm/dix";
    maintainers = with lib.maintainers; [ aarnphm ];
    platforms = lib.platforms.unix;
  };
}
