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
  delta = super.rustPlatform.buildRustPackage rec {
    pname = "delta";
    version = "0.18.0";
    src = super.fetchFromGitHub {
      owner = "dandavison";
      repo = pname;
      rev = "refs/tags/${version}";
      hash = "sha256-1UOVRAceZ4QlwrHWqN7YI2bMyuhwLnxJWpfyaHNNLYg=";
    };
    cargoHash = "sha256-/h7djtaTm799gjNrC6vKulwwuvrTHjlsEXbK2lDH+rc=";
    nativeBuildInputs = [
      super.installShellFiles
      super.pkg-config
    ];
    buildInputs =
      [
        super.oniguruma
      ]
      ++ super.lib.optionals super.stdenv.isDarwin [
        super.darwin.apple_sdk_11_0.frameworks.Foundation
      ];
    nativeCheckInputs = [super.git];
    env = {
      RUSTONIG_SYSTEM_LIBONIG = true;
    };
    postInstall = ''
      installShellCompletion --cmd delta \
        etc/completion/completion.{bash,fish,zsh}
    '';
    # test_env_parsing_with_pager_set_to_bat sets environment variables,
    # which can be flaky with multiple threads:
    # https://github.com/dandavison/delta/issues/1660
    dontUseCargoParallelTests = true;
    checkFlags = super.lib.optionals super.stdenv.isDarwin [
      "--skip=test_diff_same_non_empty_file"
    ];
    meta = with super.lib; {
      homepage = "https://github.com/dandavison/delta";
      description = "Syntax-highlighting pager for git";
      changelog = "https://github.com/dandavison/delta/releases/tag/${version}";
      license = licenses.mit;
      maintainers = with maintainers; [zowoq SuperSandro2000 figsoda];
      mainProgram = "delta";
    };
  };
  gitstatus = super.gitstatus.overrideAttrs (oldAttrs: {
    installPhase =
      oldAttrs.installPhase
      + ''
        install -Dm444 gitstatus.prompt.sh -t $out/share/gitstatus/
        install -Dm444 gitstatus.prompt.zsh -t $out/share/gitstatus/
      '';
  });
}
