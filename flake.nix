{
  description = "dix = dotfiles + nix";

  inputs = {
    nixpkgs-master.url = github:nixos/nixpkgs/master;
    nixpkgs-stable.url = github:nixos/nixpkgs/nixpkgs-21.11-darwin;
    nixpkgs-unstable.url = github:nixos/nixpkgs/nixpkgs-unstable;
    nixos-stable.url = github:nixos/nixpkgs/nixos-21.11;
    nur.url = github:nix-community/NUR;

    darwin.url = github:LnL7/nix-darwin;
    darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";

    home-manager.url = github:nix-community/home-manager;
    home-manager.inputs.nixpkgs.follows = "nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

  };

    outputs = inputs@{ self, nixpkgs, darwin, home-manager, flake-utils, ... }:
    let
      inherit (darwin.lib) darwinSystem;
      inherit (nixpkgs.lib) nixosSystem;
      inherit (home-manager.lib) homeManagerConfiguration;
      inherit (flake-utils.lib) eachDefaultSystem eachSystem;
      inherit (builtins) listToAttrs map;

      mkLib = nixpkgs:
        nixpkgs.lib.extend
          (final: prev: (import ./lib final) // home-manager.lib);

      lib = (mkLib nixpkgs);

      isDarwin = system: (builtins.elem system lib.platforms.darwin);
      homePrefix = system: if isDarwin system then "/Users" else "/home";

      # generate a base darwin configuration with the
      # specified hostname, overlays, and any extraModules applied
      mkDarwinConfig =
        { system
        , nixpkgs ? inputs.nixpkgs
        , stable ? inputs.stable
        , lib ? (mkLib inputs.nixpkgs)
        , baseModules ? [
            home-manager.darwinModules.home-manager
            ./modules/darwin
          ]
        , extraModules ? [ ]
        }:
        darwinSystem {
          inherit system;
          modules = baseModules ++ extraModules;
          specialArgs = { inherit inputs lib nixpkgs stable; };
        };

      # generate a home-manager configuration usable on any unix system
      # with overlays and any extraModules applied
      mkHomeConfig =
        { username
        , system ? "x86_64-linux"
        , nixpkgs ? inputs.nixpkgs
        , stable ? inputs.stable
        , lib ? (mkLib inputs.nixpkgs)
        , baseModules ? [
            ./modules/home-manager
            {
              home.sessionVariables = {
                NIX_PATH =
                  "nixpkgs=${nixpkgs}:stable=${stable}\${NIX_PATH:+:}$NIX_PATH";
              };
            }
          ]
        , extraModules ? [ ]
        }:
        homeManagerConfiguration rec {
          inherit system username;
          homeDirectory = "${homePrefix system}/${username}";
          extraSpecialArgs = { inherit inputs lib nixpkgs stable; };
          configuration = {
            imports = baseModules ++ extraModules ++ [ ./modules/overlays.nix ];
          };
        };
    in
    {
      checks = listToAttrs (
        # darwin checks
        (map
          (system: {
            name = system;
            value = {
              darwin =
                self.darwinConfigurations.randall-intel.config.system.build.toplevel;
              darwinServer =
                self.homeConfigurations.darwinServer.activationPackage;
            };
          })
          lib.platforms.darwin) ++
        # linux checks
        (map
          (system: {
            name = system;
            value = {
              nixos = self.nixosConfigurations.phil.config.system.build.toplevel;
              server = self.homeConfigurations.server.activationPackage;
            };
          })
          lib.platforms.linux)
      );

      darwinConfigurations = {
        randall = mkDarwinConfig {
          system = "aarch64-darwin";
          extraModules = [
            ./profiles/personal.nix
            ./modules/darwin/apps.nix
          ];
        };
        randall-intel = mkDarwinConfig {
          system = "x86_64-darwin";
          extraModules = [
            ./profiles/personal.nix
            ./modules/darwin/apps.nix
          ];
        };
        work = mkDarwinConfig {
          system = "x86_64-darwin";
          extraModules =
            [ ./profiles/work.nix ./modules/darwin/apps-minimal.nix ];
        };
      };

      homeConfigurations = {
        server = mkHomeConfig {
          username = "kclejeune";
          extraModules = [ ./profiles/home-manager/personal.nix ];
        };
        darwinServer = mkHomeConfig {
          username = "kclejeune";
          system = "x86_64-darwin";
          extraModules = [ ./profiles/home-manager/personal.nix ];
        };
        darwinServerM1 = mkHomeConfig {
          username = "kclejeune";
          system = "aarch64-darwin";
          extraModules = [ ./profiles/home-manager/personal.nix ];
        };
        workServer = mkHomeConfig {
          username = "lejeukc1";
          extraModules = [ ./profiles/home-manager/work.nix ];
        };
        vagrant = mkHomeConfig {
          username = "vagrant";
          extraModules = [ ./profiles/home-manager/personal.nix ];
        };
      };
    }
}
