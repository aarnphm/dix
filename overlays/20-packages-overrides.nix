self: super: {
  dix = super.dix or {};
  bitwarden-cli = super.bitwarden-cli.overrideAttrs (
    oldAttrs:
      with super.llvmPackages_18; {
        inherit stdenv;
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [stdenv.cc super.installShellFiles];
        postInstall =
          (oldAttrs.postInstall or "")
          + ''
            installShellCompletion --cmd bw --zsh <($out/bin/bw completion --shell zsh)
          '';
      }
  );
  gitstatus = super.gitstatus.overrideAttrs (oldAttrs: {
    installPhase =
      oldAttrs.installPhase
      + ''
        install -Dm444 gitstatus.prompt.sh -t $out/share/gitstatus/
        install -Dm444 gitstatus.prompt.zsh -t $out/share/gitstatus/
      '';
  });
  nodejs_24 = super.nodejs_24.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [super.installShellFiles];
    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        $out/bin/corepack enable --install-directory=$out/bin
      '';
  });
}
