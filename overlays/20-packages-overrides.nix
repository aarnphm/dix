self: super: {
  dix = super.dix or {};
  bitwarden-cli = super.bitwarden-cli.overrideAttrs (
    oldAttrs:
      with super.llvmPackages_18; {
        inherit stdenv;
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [stdenv.cc];
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
}
