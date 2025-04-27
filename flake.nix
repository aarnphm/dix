{
  description = "appl-mbp16 and adjacents";

  inputs = {
    # system stuff
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix.url = "https://flakehub.com/f/DeterminateSystems/nix/2.0";
    nix.inputs.nixpkgs.follows = "nixpkgs";

    # homebrew
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    nix-homebrew.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.inputs.nix-darwin.follows = "nix-darwin";
    nix-homebrew.inputs.brew-src = {
      url = "github:Homebrew/brew/master";
      flake = false;
    };

    # utilities
    systems.url = "github:nix-systems/default";
    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";

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
    nix,
    nix-darwin,
    nixpkgs,
    home-manager,
    nix-homebrew,
    git-hooks,
    ...
  } @ inputs: let
    # Define supported systems
    supportedSystems = ["aarch64-darwin" "aarch64-linux" "x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # Create overlays
    overlays = [
      (self: super: {
        dix = super.dix or {};
        neovim-stable = super.neovim;
      })
      inputs.neovim.overlays.default
      (import ./overlays/10-dev-overrides.nix)
      (import ./overlays/20-packages-overrides.nix)
      (import ./overlays/20-recurse-overrides.nix)
      (import ./overlays/30-derivations.nix)
      (import ./overlays/50-darwin-applications.nix)
    ];

    # Function to get nixpkgs for a system
    nixpkgsFor = system:
      import nixpkgs {
        inherit system overlays;
        config = {
          allowUnfree = true;
          allowBroken = !(builtins.elem system nixpkgs.lib.platforms.darwin);
        };
      };

    # App builder
    mkApp = {
      drv,
      name ? drv.pname or drv.name,
      exePath ? drv.passthru.exePath or "/bin/${name}",
    }: {
      type = "app";
      program = "${drv}${exePath}";
    };
  in {
    # Per-system attributes
    formatter = forAllSystems (
      system: let
        pkgs = nixpkgsFor system;
      in
        pkgs.alejandra
    );

    apps = forAllSystems (
      system: let
        pkgs = nixpkgsFor system;
      in {
        ubuntu-nvidia = mkApp {drv = pkgs.dix.ubuntu-nvidia;};
      }
    );

    packages = forAllSystems (
      system: let
        pkgs = nixpkgsFor system;
      in rec {
        dix = pkgs.dix;
        inherit (dix) openllm-ci;
      }
    );

    checks = forAllSystems (
      system: {
        pre-commit-check = git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            alejandra.enable = true;
            taplo.enable = true;
          };
        };
      }
    );

    devShells = forAllSystems (
      system: let
        pkgs = nixpkgsFor system;
      in {
        default = pkgs.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
          buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
        };
      }
    );

    darwinConfigurations = let
      user = "aarnphm";
      system = "aarch64-darwin";
      pkgs = nixpkgsFor system;
      specialArgs = {inherit self inputs pkgs user;};
    in {
      appl-mbp16 = nix-darwin.lib.darwinSystem {
        inherit system pkgs;
        specialArgs = specialArgs;
        modules = [
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
      system = "x86_64-linux";
      pkgs = nixpkgsFor system;
      specialArgs = {inherit self inputs pkgs user;};
    in {
      paperspace = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = specialArgs;
        modules = [
          nix.homeModules.default
          ./hm
        ];
      };
    };
  };
}
