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

  outputs = { self, nixpkgs, nix-darwin, home-manager, flake-utils, ... }@inputs:
    let
      inherit (flake-utils.lib) eachSystemMap;

      isDarwin = system: (builtins.elem system inputs.nixpkgs.lib.platforms.darwin);
      homePrefix = system:
        if isDarwin system
        then "/Users"
        else "/home";

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
      packages.aarch64-darwin.dix = darwin-pkgs.dix;
      packages.x86_64-linux.dix = linux-pkgs.dix;

      darwinConfigurations = {
        appl-mbp16 = nix-darwin.lib.darwinSystem rec {
          system = "aarch64-darwin";
          pkgs = darwin-pkgs;
          specialArgs = { inherit self inputs user pkgs; };
          modules = [
            ./darwin/appl-mbp16.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.aarnphm.imports = [ ./hm ];
                backupFileExtension = "backup-from-hm";
                extraSpecialArgs = { inherit user pkgs; };
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
          modules = [ ./hm ];
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
        (import ./overlays/10-dev-overrides.nix)
        (import ./overlays/20-packages-overrides.nix)
        (import ./overlays/30-derivations.nix)
      ];

      darwinOverlays = self.linuxOverlays ++ [
        # custom packages specifics to darwin
        (import ./overlays/50-darwin-applications.nix)
      ];
    };
}
