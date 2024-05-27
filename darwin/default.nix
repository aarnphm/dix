{ inputs, nixpkgs, darwin, vars, editor, neovim, ... }:

let
  system = "aarch64-darwin";
  pkgs = import nixpkgs {
    inherit system;
    overlays = [
      neovim.overlays.default
      (self: super: {
        aarnphm-editor = pkgs.stdenv.mkDerivation {
          name = "aarnphm-editor";
          src = editor;
          buildCommand = ''
            mkdir -p $out
            cp -r $src/* $out
          '';
        };
      })
    ];
    config = {
      allowUnfree = true;
    };
  };
in
{
  appl-mbp16 = darwin.lib.darwinSystem {
    inherit system;
    specialArgs = { inherit inputs system pkgs vars; };
    modules = [ ./appl-mbp16.nix ];
  };
}
