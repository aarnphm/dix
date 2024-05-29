{ pkgs, ... }:
pkgs.stdenv.mkDerivation (finalAttrs: {
  name = "common.zsh";
  src = ./.;
  installPhase = ''
    mkdir -p $out/share/zsh
    cp  -r ./ $out/share/zsh
  '';
})
