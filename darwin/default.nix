{ inputs, nixpkgs, darwin, vars, neovim, ... }:

let
  system = "aarch64-darwin";
  pkgs = import nixpkgs {
    inherit system;
    config.allowUnfree = true;
    overlays = [ neovim.overlays.default ];
  };
in
{
  appl-mbp16 = darwin.lib.darwinSystem {
    inherit system;
    specialArgs = { inherit inputs system pkgs vars; };
    modules = [ ./appl-mbp16.nix ];
  };
}
