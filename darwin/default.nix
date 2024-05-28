{ inputs, nixpkgs, darwin, home-manager, neovim, nvim-config, ... }:
let
  system = "aarch64-darwin";
  user = "aarnphm";
  pkgs = import nixpkgs {
    inherit system;
    overlays = [
      neovim.overlays.default
      (self: super: {
        nvim-config = pkgs.stdenv.mkDerivation {
          name = "nvim-config";
          src = nvim-config;
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
    specialArgs = { inherit inputs system user pkgs; };
    modules = [
      ./appl-mbp16.nix
      home-manager.darwinModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users."${user}" = import ./home.nix;
      }
    ];
  };
}
