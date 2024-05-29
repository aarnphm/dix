self: super:
{
  dix = super.dix or { } // {
    sketchybar = super.sketchybar.overrideAttrs (oldAttrs: {
      installPhase = oldAttrs.installPhase + ''
        mkdir -p $out/plugins
        cp -r ./plugins $out
      '';
    });
  };
  pyenv = super.pyenv.overrideAttrs (oldAttrs: {
    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -R bin "$out/bin"
      cp -R libexec "$out/libexec"
      cp -R plugins "$out/plugins"
      cp -R completions "$out/completions"

      runHook postInstall
    '';
  });
}

