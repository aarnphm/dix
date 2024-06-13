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
    neovim.url = "github:nix-community/neovim-nightly-overlay";
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix/main";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # config stuff
    editor-nix.url = "github:aarnphm/editor";
    editor-nix.flake = false;
    emulator-nix.url = "github:aarnphm/emulators";
    emulator-nix.flake = false;
  };

  nixConfig = {
    trusted-substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" "https://cuda-maintainers.cachix.org" ];
    trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=" ];
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, nix-homebrew, flake-utils, ... }@inputs:
    let
      inherit (flake-utils.lib) eachSystemMap;

      forAllSystems = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ];

      darwin-pkgs = import nixpkgs {
        system = "aarch64-darwin";
        overlays = self.darwinOverlays;
        config = {
          allowUnfree = true;
        };
      };

      linux-pkgs = import nixpkgs {
        system = "x86_64-linux";
        overlays = self.linuxOverlays;
        config = {
          allowUnfree = true;
          allowBroken = true;
        };
      };
    in
    {
      packages.aarch64-darwin = rec {
        dix = darwin-pkgs.dix;
        inherit (dix) openllm-ci;
      };
      packages.x86_64-linux = rec {
        dix = linux-pkgs.dix;
        inherit (dix) openllm-ci;
      };

      overlays = {
        default = self.linuxOverlays;
        dix = self.darwinOverlays;
      };

      darwinConfigurations =
        let
          user = "aarnphm";
        in
        {
          appl-mbp16 = nix-darwin.lib.darwinSystem rec {
            system = "aarch64-darwin";
            pkgs = darwin-pkgs;
            specialArgs = { inherit self inputs user pkgs; };
            modules = [
              ./darwin/appl-mbp16.nix
              nix-homebrew.darwinModules.nix-homebrew
              {
                nix-homebrew = {
                  inherit user;
                  enable = true;
                  enableRosetta = true;

                  # Optional: Declarative tap management
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

      homeConfigurations = {
        paperspace = home-manager.lib.homeManagerConfiguration rec {
          pkgs = linux-pkgs;
          extraSpecialArgs = {
            inherit self inputs pkgs;
            user = "paperspace";
          };
          modules = [
            inputs.nix.homeManagerModules.default
            ./hm
          ];
        };
      };

      linuxOverlays = [
        inputs.neovim.overlays.default
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
      ];

      darwinOverlays = self.linuxOverlays ++ [
        # custom packages specifics to darwin
        (import ./overlays/50-darwin-applications.nix)
      ];
    };
}
