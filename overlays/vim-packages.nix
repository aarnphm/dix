self: super:
let
  xcrunHost = super.runCommand "xcrunHost" { } ''
    mkdir -p $out/bin
    ln -s /usr/bin/xcrun $out/bin
  '';
in
{
  vimPlugins = super.vimPlugins // {
    vim-nix = super.vimPlugins.vim-nix.overrideAttrs (drv: {
      name = "vim-nix-custom";
      src = super.dix.vim-nix;
    });
  };
  emulators = super.stdenv.mkDerivation {
    name = "emulators";
    src = super.dix.emulator-nix;
    buildCommand = ''
      mkdir -p $out
      cp -r $src/* $out
    '';
  };
  bitwarden-cli = super.buildNpmPackage {
    name = "bitwarden-cli";
    src = super.dix.bitwarden-cli;
    nodejs = super.nodejs_20;

    env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";

    npmDepsHash = "sha256-fjYez3nSDsG5kYtrun3CkDCz1GNAjNlwPzEL+/9qQRU=";

    nativeBuildInputs = [
      super.python3
    ] ++ super.lib.optionals super.stdenv.isDarwin [
      super.darwin.cctools
      xcrunHost
    ];

    makeCacheWritable = true;

    npmBuildScript = "build:prod";

    npmWorkspace = "apps/cli";

    postInstall = ''
      installShellCompletion --zsh --name _bw <($out/bin/bw completion --shell zsh)
    '';

    meta = {
      mainProgram = "bw";
    };
  };
}
