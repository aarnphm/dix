self: super: {
  zsh-dix = super.stdenv.mkDerivation {
    name = "dix.zsh";
    src = ./.;
    installPhase = ''
      mkdir -p $out/share/zsh
      cp  -r ./site-functions/ $out/share/zsh/site-functions
      cp *.zsh $out/share/zsh
    '';
  };
}
