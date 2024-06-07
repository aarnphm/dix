{
  description = "appl-mbp16 and adjacents";

  inputs = {
    # system stuff
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";

    # config stuff
    neovim.url = "github:nix-community/neovim-nightly-overlay";
    vim-nix = {
      url = "github:aarnphm/editor";
      flake = false;
    };
    emulator-nix = {
      url = "git+ssh://git@github.com/aarnphm/emulators.git?ref=main";
      flake = false;
    };
    bitwarden-cli = {
      url = "github:bitwarden/clients/cli-v2024.4.1";
      flake = false;
    };
  };

  outputs =
    { self
    , nixpkgs
    , nix-darwin
    , home-manager
    , neovim
    , vim-nix
    , emulator-nix
    , bitwarden-cli
    , ...
    }@inputs:
    let
      user = "aarnphm";

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
        };
      };
    in
    {
      packages.aarch64-darwin = {
        dix = darwin-pkgs.dix;
      };
      packages.x86_64-linux = {
        dix = linux-pkgs.dix;
      };

      darwinConfigurations = {
        appl-mbp16 = nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          specialArgs = {
            inherit self inputs user;
            pkgs = darwin-pkgs;
          };
          modules = [
            ./darwin/appl-mbp16.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users."${user}" = {
                  imports = [ ./hm ];
                };
                backupFileExtension = "backup-from-hm";
                extraSpecialArgs = {
                  inherit user;
                  pkgs = darwin-pkgs;
                };
                verbose = true;
              };
            }
          ];
        };
      };

      darwinOverlays = [
        neovim.overlays.default
        # custom packages
        (self: super: {
          dix = super.dix or { } // {
            inherit vim-nix emulator-nix bitwarden-cli;
          };

          python3-tools = super.buildEnv {
            name = "python3-tools";
            paths = [ (self.python3.withPackages (ps: with ps; [ pynvim ])) ];
          };
        })
        (import ./overlays/zsh-dix.nix)
        (import ./overlays/derivations.nix)
        (import ./overlays/packages-overrides.nix)
        (import ./overlays/vim-packages.nix)
      ];

      linuxOverlays = [
        neovim.overlays.default
        # custom packages
        (self: super: {
          dix = super.dix or { } // {
            inherit vim-nix emulator-nix bitwarden-cli;
          };

          python3-tools = super.buildEnv {
            name = "python3-tools";
            paths = [ (self.python3.withPackages (ps: with ps; [ pynvim ])) ];
          };
        })
        (import ./overlays/zsh-dix.nix)
        (import ./overlays/derivations.nix)
        (import ./overlays/packages-overrides.nix)
        (import ./overlays/vim-packages.nix)
      ];
    };
}
