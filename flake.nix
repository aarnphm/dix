{
  description = "appl-mbp16 and adjacents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim = {
      url = "github:nix-community/neovim-nightly-overlay";
    };
  };

  outputs = inputs@{ self, darwin, neovim, nixpkgs }:
    let
      vars = {
        # dir
        homeDir = builtins.getEnv "HOME";
        wsDir = "$HOME/workspace";
        configDir = "$HOME/.config";
        localDir = "$HOME/.local";
        cacheDir = "$HOME/.cache";

        # general based
        user = "aarnphm";
        editor = "nvim";
        terminal = "alacritty";
        apperance = "light"; # dark | light
        colorscheme = "rose-pine";
      };
    in
    {
      darwinConfigurations = (
        import ./darwin {
          inherit (nixpkgs) lib;
          inherit inputs nixpkgs darwin vars neovim;
        }
      );

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."appl-mbp16".pkgs;
    };
}
