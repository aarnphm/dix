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

    # utilities
    flake-utils.url = "github:numtide/flake-utils";

    # config stuff
    neovim.url = "github:nix-community/neovim-nightly-overlay";
    editor-nix = {
      url = "github:aarnphm/editor";
      flake = false;
    };
    emulator-nix = {
      url = "github:aarnphm/emulators";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, ... }@inputs:
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

      linuxOverlays = with inputs; [
        neovim.overlays.default
        (self: super: {
          dix = super.dix or { } // {
            inherit editor-nix emulator-nix;
          };

          python3-tools = super.buildEnv {
            name = "python3-tools";
            paths = [ (self.python3.withPackages (ps: with ps; [ pynvim ])) ];
          };
        })
        (import ./overlays/zsh-dix.nix)
        (import ./overlays/derivations.nix)
        (import ./overlays/packages-overrides.nix)
      ];

      darwinOverlays = self.linuxOverlays ++ [
        # custom packages specifics to darwin
        (import ./overlays/darwin-applications.nix)
      ];
    };
}
