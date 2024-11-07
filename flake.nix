{
  description = "appl-mbp16 and adjacents";

  inputs = {
    # system stuff
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    nix.url = "https://flakehub.com/f/DeterminateSystems/nix/2.0";
    nix.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    # homebrew
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nix-homebrew.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.inputs.nix-darwin.follows = "nix-darwin";
    nix-homebrew.inputs.flake-utils.follows = "flake-utils";

    # utilities
    systems.url = "github:nix-systems/default";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.systems.follows = "systems";
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks.inputs.nixpkgs-stable.follows = "nixpkgs";

    # config stuff
    neovim.url = "github:nix-community/neovim-nightly-overlay";
    neovim.inputs.nixpkgs.follows = "nixpkgs";
    neovim.inputs.git-hooks.follows = "git-hooks";
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
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowBroken = !(builtins.elem system nixpkgs.lib.platforms.darwin);
          };
          overlays = [
            (self: super: {
              dix = super.dix or {};
              python3-tools = super.buildEnv {
                name = "python3-tools";
                paths = [(self.python311.withPackages (ps: with ps; [pynvim]))];
                meta = {mainProgram = "python";};
              };
              neovim-stable = super.neovim;
            })
            inputs.neovim.overlays.default

            # custom overlays
            (import ./overlays/10-dev-overrides.nix)
            (import ./overlays/20-packages-overrides.nix)
            (import ./overlays/20-recurse-overrides.nix)
            (import ./overlays/30-derivations.nix)

            # custom packages specifics to darwin
            (import ./overlays/50-darwin-applications.nix)
          ];
        };
        genSpecialArgs = user: {inherit self inputs pkgs user;};
      in {
        formatter = pkgs.alejandra;

        apps = {
          ubuntu-nvidia = flake-utils.lib.mkApp {drv = pkgs.dix.ubuntu-nvidia;};
        };

        packages = rec {
          dix = pkgs.dix;
          inherit (dix) openllm-ci;

          darwinConfigurations = let
            user = "aarnphm";
          in {
            appl-mbp16 = nix-darwin.lib.darwinSystem rec {
              inherit system pkgs;
              specialArgs = genSpecialArgs user;
              modules = [
                inputs.nix.darwinModules.default
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
                ./darwin/appl-mbp16.nix
              ];
            };
          };

          homeConfigurations = let
            user = "paperspace";
          in {
            paperspace = home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              extraSpecialArgs = genSpecialArgs user;
              modules = [
                inputs.nix.homeManagerModules.default
                ./hm
              ];
            };
          };
        };

        checks = {
          pre-commit-check = inputs.git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              alejandra.enable = true;
              taplo.enable = true;
            };
          };
        };

        devShells = {
          default = pkgs.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
          };
        };
      }
    );
}
