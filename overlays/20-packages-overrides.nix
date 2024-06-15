self: super: {
  dix = super.dix or {};
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
  gitstatus = super.gitstatus.overrideAttrs (oldAttrs: {
    installPhase =
      oldAttrs.installPhase
      + ''
        install -Dm444 gitstatus.prompt.sh -t $out/share/gitstatus/
        install -Dm444 gitstatus.prompt.zsh -t $out/share/gitstatus/
      '';
  });
  tree-sitter = super.tree-sitter.override {webUISupport = true;};
  neovim = super.neovim.overrideAttrs (oldAttrs: {
    preConfigure =
      oldAttrs.preConfigure
      + super.lib.concatStrings (super.lib.mapAttrsToList
        (language: grammar: ''
          ln -sf ${grammar}/parser $out/lib/nvim/parser/${super.lib.strings.removePrefix "tree-sitter-" language}.so
        '')
        self.tree-sitter.builtGrammars);
  });
}
