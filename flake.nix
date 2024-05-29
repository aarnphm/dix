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
    flake-utils.url = "github:numtide/flake-utils";

    # config stuff
    neovim.url = "github:nix-community/neovim-nightly-overlay";
    vim-nix.url = "github:aarnphm/editor";
    vim-nix.flake = false;
    emulator-nix.url = "git+ssh://git@github.com/aarnphm/emulators.git";
    emulator-nix.flake = false;
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, flake-utils, neovim, vim-nix, emulator-nix, ... }@inputs:
    let
      user = "aarnphm";
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        overlays = self.darwinOverlays;
        config = { allowUnfree = true; };
      };
    in
    {
      darwinOverlays = [
        neovim.overlays.default
        # custom packages
        (self: super: {
          dix = super.dix or { } // { inherit vim-nix emulator-nix; };

          python3-tools = super.buildEnv {
            name = "python3-tools";
            paths = [ (self.python3.withPackages (ps: with ps; [ pynvim ])) ];
          };
        })
        (import ./overlays/dix.zsh)
        (import ./overlays/packages-overrides.nix)
        (import ./overlays/vim-packages.nix)
      ];

      darwinConfigurations = {
        appl-mbp16 = nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit self inputs system user pkgs; };
          modules = [
            ./darwin/appl-mbp16.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users."${user}" = import ./darwin/home.nix;
            }
          ];
        };
      };
      darwinPackages = self.darwinConfigurations."apple-mbp16".pkgs;
    };
}
