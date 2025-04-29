self: super: {
  dix = super.dix or {};
  bitwarden-cli = super.bitwarden-cli.overrideAttrs (
    oldAttrs: {
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [super.llvmPackages_18.stdenv.cc];
      stdenv = super.llvmPackages_18.stdenv;
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
