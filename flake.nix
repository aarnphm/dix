{
  description = "appl-mbp16 and adjacents";

  inputs = {
    # system stuff
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    neovim.url = "github:nix-community/neovim-nightly-overlay";

    # config stuff
    nvim-config = {
      url = "github:aarnphm/editor";
      flake = false;
    };
    emulator-config = {
      url = "git+ssh://git@github.com/aarnphm/emulators.git";
      flake = false;
    };

    # shell stuff
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, darwin, home-manager, neovim, ... }@inputs:
    {
      darwinConfigurations = (
        import ./darwin {
          inherit (nixpkgs) lib;
          inherit inputs nixpkgs darwin home-manager neovim;
        }
      );
    };
}
