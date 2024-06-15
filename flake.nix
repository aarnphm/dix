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
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.inputs.nixpkgs-stable.follows = "nixpkgs";

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
    trusted-substituters = ["https://nix-community.cachix.org" "https://cache.nixos.org" "https://cuda-maintainers.cachix.org"];
    trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="];
  };

  outputs = {
    self,
    nix-darwin,
    nixpkgs,
    home-manager,
    flake-utils,
    ...
  } @ inputs: let
    genSpecialArgs = {
      pkgs,
      user,
    }: {inherit self inputs pkgs user;};

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowBroken = !(builtins.elem system nixpkgs.lib.platforms.darwin);
        };
        overlays = [
          (self: super: {
            dix = super.dix or {} // {editor-nix = inputs.editor-nix;};

            python3-tools = super.buildEnv {
              name = "python3-tools";
              paths = [(self.python3.withPackages (ps: with ps; [pynvim]))];
              meta = {mainProgram = "python";};
            };
          })
          inputs.neovim.overlays.default
          inputs.agenix.overlays.default

          # custom overlays
          (import ./overlays/10-dev-overrides.nix)
          (import ./overlays/20-packages-overrides.nix)
          (import ./overlays/20-recurse-overrides.nix)
          (import ./overlays/30-derivations.nix)

          # custom packages specifics to darwin
          (import ./overlays/50-darwin-applications.nix)
        ];
      };
  in
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = mkPkgs system;
      in {
        formatter = pkgs.alejandra;

        apps = {
          ubuntu-nvidia = flake-utils.lib.mkApp {drv = pkgs.dix.ubuntu-nvidia;};
        };

        packages = {
          inherit (pkgs.dix) openllm-ci;
        };

        checks = {
          pre-commit-check = inputs.git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              alejandra.enable = true;
            };
          };
        };

        devShells = {
          default = pkgs.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
          };
        };

        legacyPackages = {
          darwinConfigurations = let
            user = "aarnphm";
          in {
            appl-mbp16 = nix-darwin.lib.darwinSystem rec {
              inherit system pkgs;
              specialArgs = genSpecialArgs {inherit pkgs user;};
              modules = [
                ./darwin/appl-mbp16.nix
                ./lib
                inputs.nix.darwinModules.default
                inputs.agenix.darwinModules.default
                inputs.nix-homebrew.darwinModules.nix-homebrew
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
                    users."${user}".imports = [./hm];
                    backupFileExtension = "backup-from-hm";
                    extraSpecialArgs = specialArgs;
                    verbose = true;
                  };
                }
              ];
            };
          };

          homeConfigurations = let
            user = "paperspace";
          in {
            paperspace = home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              extraSpecialArgs = genSpecialArgs {inherit pkgs user;};
              modules = [
                ./hm
                ./lib
                inputs.nix.homeManagerModules.default
                inputs.agenix.homeManagerModules.default
              ];
            };
          };
        };
      }
    );
}
