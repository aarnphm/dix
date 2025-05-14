{
  description = "appl-mbp16 and adjacents setup for Aaron";

  inputs = {
    # system stuff
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix = {
      url = "https://flakehub.com/f/DeterminateSystems/nix/2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # homebrew
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nix-darwin.follows = "nix-darwin";
      };
    };
    # utilities
    git-hooks = {
      url = "github:cachix/git-hooks.nix/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim = {
      url = "github:nix-community/neovim-nightly-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        git-hooks.follows = "git-hooks";
      };
    };
    # atuin
    atuin = {
      url = "github:atuinsh/atuin";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  nixConfig = {
    trusted-substituters = ["https://nix-community.cachix.org" "https://cache.nixos.org" "https://cuda-maintainers.cachix.org"];
    trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="];
  };

  # meta function: https://github.com/NixOS/nixpkgs/blob/master/lib/meta.nix
  outputs = {
    self,
    nix,
    nix-darwin,
    nixpkgs,
    home-manager,
    git-hooks,
    neovim,
    atuin,
    ...
  } @ inputs: let
    # Create overlays
    overlays = [
      (self: super: {
        dix = super.dix or {};
        neovim-stable = super.neovim;
      })
      # additional packages
      neovim.overlays.default
      nix-darwin.overlays.default
      atuin.overlays.default
      # custom dix's overlays
      (import ./overlays/10-dev-overrides.nix)
      (import ./overlays/20-packages-overrides.nix)
      (import ./overlays/20-recurse-overrides.nix)
      (import ./overlays/30-derivations.nix)
    ];
  in
    builtins.foldl' nixpkgs.lib.recursiveUpdate {
      darwinConfigurations = let
        user = "aarnphm";
        system = "aarch64-darwin";
        pkgs = import nixpkgs {
          inherit system overlays;
          config = {
            allowUnfree = true;
            allowUnsupportedSystem = true;
          };
        };
        specialArgs = {
          inherit self inputs pkgs user;
          systemVar = system;
        };
      in {
        appl-mbp16 = nix-darwin.lib.darwinSystem {
          inherit system pkgs specialArgs;
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
            ./darwin
          ];
        };
      };

      homeConfigurations = builtins.foldl' nixpkgs.lib.recursiveUpdate {} (
        builtins.map (
          user: let
            system = "x86_64-linux";
            pkgs = import nixpkgs {
              inherit system overlays;
              config = {
                allowUnfree = true;
                allowBroken = true;
              };
            };
            specialArgs = {
              inherit self inputs pkgs user;
              systemVar = system;
            };
          in {
            ubuntu = home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              extraSpecialArgs = specialArgs;
              modules = [
                nix.homeModules.default
                ./hm
              ];
            };
          }
        ) ["ubuntu" "paperspace"]
      );
    } (
      builtins.map (
        system: let
          pkgs = import nixpkgs {
            inherit system overlays;
            config = {
              allowUnfree = true;
              allowBroken = !(builtins.elem system nixpkgs.lib.platforms.darwin);
              allowUnsupportedSystem = true;
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
          formatter.${system} = pkgs.alejandra;
          apps.${system} = builtins.listToAttrs (
            builtins.map (
              name: {
                inherit name;
                value = mkApp {drv = pkgs.dix.${name};};
              }
            ) [
              "lambda"
              "ubuntu-nvidia"
              "aws-credentials"
              "bootstrap"
            ]
          );
          packages.${system} = with pkgs; {inherit dix;};
          checks.${system} = {
            pre-commit-check = git-hooks.lib.${system}.run {
              src = ./.;
              hooks = {
                alejandra.enable = true;
                statix.enable = true;
              };
            };
          };

          devShells.${system} = {
            default = pkgs.mkShell {
              inherit (self.checks.${system}.pre-commit-check) shellHook;
              buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
            };
          };
        }
      ) ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"]
    );
}
