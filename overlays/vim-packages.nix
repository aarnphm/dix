self: super:
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
}
