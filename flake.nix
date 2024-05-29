{
  description = "appl-mbp16 and adjacents";

  inputs = {
    # system stuff
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim.url = "github:nix-community/neovim-nightly-overlay";
    # config stuff
    nvim-nix = {
      url = "github:aarnphm/editor";
      flake = false;
    };
    emulator-nix = {
      url = "git+ssh://git@github.com/aarnphm/emulators.git";
      flake = false;
    };

    # shell stuff
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, neovim, nvim-nix, emulator-nix, ... }@inputs: {
    darwinOverlays = [
      (self: super: {
        aarnphm = super.aarnphm or { } // {
          inherit nvim-nix emulator-nix;
        };
      })
      # custom packages
      (import ./nixpkgs/overlays/common.zsh)
      # general overlays
      neovim.overlays.default
    ];

    packages.aarch64-darwin =
      let
        system = "aarch64-darwin";
        pkgs = import nixpkgs {
          inherit system;
          overlays = self.darwinOverlays;
          config = {
            allowUnfree = true;
          };
        };
      in
      {
        aarnphm = pkgs.aarnphm;
        python = pkgs.python3.pkgs.callPackage ({ buildEnv, python, pynvim }: buildEnv {
          name = "${python.name}-tools";
          paths = [ pynvim ];
        });
      };

    darwinConfigurations = (
      import ./darwin {
        inherit (nixpkgs) lib;
        system = "aarch64-darwin";
        inherit inputs nixpkgs nix-darwin home-manager neovim;
      }
    );
  };
}
