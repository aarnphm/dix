self: super:
{
  vimPlugins = super.vimPlugins // {
    vim-nix = super.vimPlugins.vim-nix.overrideAttrs (drv: {
      name = with import ../lib/versions.nix; "vim-nix-${flakeVersion super.dix.vim-nix}";
      src = super.dix.vim-nix;
    });
  };
  emulators = super.stdenv.mkDerivation {
    name = with import ../lib/versions.nix; "emulators-${flakeVersion super.dix.emulator-nix}";
    src = super.dix.emulator-nix;
    buildCommand = ''
      mkdir -p $out
      cp -r $src/* $out
    '';
  };
}
