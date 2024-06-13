{
  description = "appl-mbp16 and adjacents";

  inputs = {
    # system stuff
    nix.url = "https://flakehub.com/f/DeterminateSystems/nix/2.0";
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # homebrew
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    homebrew-bundle.url = "github:homebrew/homebrew-bundle";
    homebrew-bundle.flake = false;
    homebrew-core.url = "github:homebrew/homebrew-core";
    homebrew-core.flake = false;
    homebrew-cask.url = "github:homebrew/homebrew-cask";
    homebrew-cask.flake = false;

    # utilities
    systems.url = "github:nix-systems/default";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";

    # secrets stuff
    agenix.url = "github:ryantm/agenix/main";
    agenix.inputs.darwin.follows = "nix-darwin";
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.systems.follows = "systems";

    # config stuff
    neovim.url = "github:nix-community/neovim-nightly-overlay";
    neovim.inputs.nixpkgs.follows = "nixpkgs";
    editor-nix.url = "github:aarnphm/editor";
    editor-nix.flake = false;
  };

  nixConfig = {
    trusted-substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" "https://cuda-maintainers.cachix.org" ];
    trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=" ];
  };

  outputs = { self, nix, nixpkgs, nix-darwin, home-manager, agenix, flake-utils, nix-homebrew, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowBroken = !(builtins.elem system inputs.nixpkgs.lib.platforms.darwin);
          };
          overlays = [
            inputs.neovim.overlays.default
            inputs.agenix.overlays.default
            (self: super: {
              dix = super.dix or { } //
                {
                  editor-nix = inputs.editor-nix;
                  emulator-nix = inputs.emulator-nix;
                };

              python3-tools = super.buildEnv {
                name = "python3-tools";
                paths = [ (self.python3.withPackages (ps: with ps; [ pynvim ])) ];
                meta = { mainProgram = "python"; };
              };
            })
            (import ./overlays/10-dev-overrides.nix)
            (import ./overlays/20-packages-overrides.nix)
            (import ./overlays/20-recurse-overrides.nix)
            (import ./overlays/30-derivations.nix)

            # custom packages specifics to darwin
            (import ./overlays/50-darwin-applications.nix)
          ];
        };
      in
      {
        packages = rec {
          dix = pkgs.dix;
          inherit (dix) openllm-ci;

          darwinConfigurations =
            let
              user = "aarnphm";
            in
            {
              appl-mbp16 = nix-darwin.lib.darwinSystem rec {
                inherit system pkgs;
                specialArgs = { inherit self inputs user pkgs; };
                modules = [
                  ./darwin/appl-mbp16.nix
                  ./lib
                  nix.darwinModules.default
                  agenix.darwinModules.default
                  nix-homebrew.darwinModules.nix-homebrew
                  {
                    nix-homebrew = {
                      inherit user;
                      enable = true;
                      enableRosetta = true;
                      taps = {
                        "homebrew/homebrew-core" = inputs.homebrew-core;
                        "homebrew/homebrew-cask" = inputs.homebrew-cask;
                        "homebrew/homebrew-bundle" = inputs.homebrew-bundle;
                      };
                      mutableTaps = false;
                      autoMigrate = true;
                    };
                  }
                  home-manager.darwinModules.home-manager
                  {
                    home-manager = {
                      useGlobalPkgs = true;
                      useUserPackages = true;
                      users."${user}".imports = [ ./hm ];
                      backupFileExtension = "backup-from-hm";
                      extraSpecialArgs = specialArgs;
                      verbose = true;
                    };
                  }
                ];
              };
            };

          homeConfigurations =
            let
              user = "paperspace";
            in
            pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
              paperspace = home-manager.lib.homeManagerConfiguration rec {
                inherit pkgs;
                extraSpecialArgs = { inherit self inputs pkgs user; };
                modules = [
                  ./hm
                  ./lib
                  nix.homeManagerModules.default
                  agenix.homeManagerModules.default
                ];
              };
            };
        };
      }
    );
}
