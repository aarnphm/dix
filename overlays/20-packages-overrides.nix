{self}: final: prev: {
  bitwarden-cli = prev.bitwarden-cli.overrideAttrs (
    oldAttrs:
      with prev.llvmPackages_18;
        {
          inherit stdenv;
          nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [stdenv.cc prev.installShellFiles];
          postInstall =
            (oldAttrs.postInstall or "")
            + ''
              installShellCompletion --cmd bw --zsh <($out/bin/bw completion --shell zsh)
            '';
        }
        // rec {
          version = "2025.4.0";
          src = prev.fetchFromGitHub {
            owner = "bitwarden";
            repo = "clients";
            tag = "cli-v${version}";
            hash = "sha256-8jVKwqKhTfhur226SER4sb1i4dY+TjJRYmOY8YtO6CY=";
          };
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
}
