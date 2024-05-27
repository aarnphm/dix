{
  description = "appl-mbp16 and adjacents";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };

    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim = {
      url = "github:nix-community/neovim-nightly-overlay";
    };

    editor = {
      url = "github:aarnphm/editor";
      flake = false;
    };
  };

  outputs = inputs@{ self, darwin, neovim, nixpkgs, editor }:
    let
      vars = {
        # dir
        homeDir = "$HOME";
        wsDir = "$HOME/workspace";
        configDir = "$HOME/.config";
        localDir = "$HOME/.local";
        cacheDir = "$HOME/.cache";

        # general based
        user = "aarnphm";
        terminal = "alacritty";
      };
    in
    {
      darwinConfigurations = (
        import ./darwin {
          inherit (nixpkgs) lib;
          inherit inputs nixpkgs darwin vars editor neovim;
        }
      );

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."appl-mbp16".pkgs;
    };
}
