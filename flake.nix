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

  outputs = { self, nix-darwin, home-manager, flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        isDarwin = builtins.elem system inputs.nixpkgs.lib.platforms.darwin;

        pkgs = import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            allowBroken = !(isDarwin);
          };
          overlays = [
            (self: super: {
              dix = super.dix or { } // { editor-nix = inputs.editor-nix; };

              python3-tools = super.buildEnv {
                name = "python3-tools";
                paths = [ (self.python3.withPackages (ps: with ps; [ pynvim ])) ];
                meta = { mainProgram = "python"; };
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

        genSpecialArgs = user: { inherit self inputs user pkgs; };
      in
      {
        apps = {
          ubuntu-nvidia = flake-utils.lib.mkApp {
            drv = pkgs.writeShellApplication rec{
              name = "ubuntu-nvidia";
              runtimeInputs = with pkgs; [
                apt
                (runCommand "ubuntuDriverHost" { } ''
                  mkdir -p $out/bin
                  ln -s /usr/bin/ubuntu-drivers $out/bin
                '')
              ];
              text = ''
                if [ $# -ne 1 ]; then
                  AVAILABLE_DRIVERS=$(ubuntu-drivers list)

                  echo ""
                  echo "Usage: ${name} <driver_name>"
                  echo ""
                  echo "Available drivers:"
                  echo ""
                  echo "$AVAILABLE_DRIVERS"
                  exit 1
                fi

                DEBUG="''${DEBUG:-false}"

                # check if DEBUG is set, then use set -x, otherwise ignore
                if [ "$DEBUG" = true ]; then
                  set -x
                  echo "running path: $0"
                fi

                DRIVER_NAME="nvidia-driver-$1"
                DRIVER_PACKAGE="nvidia:$1"
                UTILS_PACKAGE="nvidia-utils-$1"

                # Use ubuntu-drivers to find the appropriate driver package
                NVIDIA_PACKAGE="$(ubuntu-drivers devices | grep "$DRIVER_NAME" | awk '{print $3}')"

                if [ -z "$NVIDIA_PACKAGE" ]; then
                  echo "Error: Driver '$DRIVER_NAME' not found."
                  exit 1
                fi

                # Check if the driver name contains "-server"
                if [[ "$DRIVER_NAME" == *"-server"* ]]; then
                  GPGPU_FLAG="--gpgpu"
                else
                  GPGPU_FLAG=""
                fi

                # Install the NVIDIA driver package using apt
                sudo ubuntu-drivers install "$GPGPU_FLAG" "$DRIVER_PACKAGE"
                sudo apt update && sudo apt install -y "$UTILS_PACKAGE"

                echo "NVIDIA driver '$DRIVER_NAME' has been installed."
                echo "Please reboot your system for the changes to take effect."
              '';
            };
          };
        };
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
                specialArgs = genSpecialArgs user;
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
            {
              paperspace = home-manager.lib.homeManagerConfiguration {
                inherit pkgs;
                extraSpecialArgs = genSpecialArgs user;
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
