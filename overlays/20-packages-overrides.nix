{self}: final: prev: {
  bitwarden-cli = prev.bitwarden-cli.overrideAttrs (
    oldAttrs:
      with prev.llvmPackages_18; {
        inherit stdenv;
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [stdenv.cc prev.installShellFiles];
        postInstall =
          (oldAttrs.postInstall or "")
          + ''
            installShellCompletion --cmd bw --zsh <($out/bin/bw completion --shell zsh)
          '';
      }
  );
  gitstatus = prev.gitstatus.overrideAttrs (oldAttrs: {
    installPhase =
      oldAttrs.installPhase
      + ''
        install -Dm444 gitstatus.prompt.sh -t $out/share/gitstatus/
        install -Dm444 gitstatus.prompt.zsh -t $out/share/gitstatus/
      '';
  });
  nodejs_24 = prev.nodejs_24.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [prev.installShellFiles];
    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        $out/bin/corepack enable --install-directory=$out/bin
      '';
  });
}
