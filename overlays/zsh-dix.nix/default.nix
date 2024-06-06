self: super: {
  zsh-dix = super.stdenv.mkDerivation {
    name = "dix.zsh";
    src = ./.;
    installPhase = ''
      mkdir -p $out/share/zsh
      cp *.zsh $out/share/zsh
    '';
  };
}
