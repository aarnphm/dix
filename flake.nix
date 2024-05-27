{
  description = "appl-mbp16 and adjacents";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay/fix-build";
  };

  outputs = inputs@{ self, nix-darwin, neovim-nightly-overlay, nixpkgs }:
    let
      homeDir = builtins.getEnv "HOME";
      wsDir = builtins.getEnv "WORKSPACE";
      configuration = { pkgs, ... }: {
        # List packages installed in system profile. To search by name, run:
        # $ nix-env -qaP | grep wget
        # nix-env -i /nix/store/ws2fbwf7xcmnhg2hlvq43qg22j06w5jb-niv-0.2.19-bin --option binary-caches https://cache.nixos.org
        environment = {
          darwinConfig = "${wsDir}/dix";
          systemPackages = with pkgs; [
            # editor
            vim
            neovim-developer
            buf
            protolint
            eclint
            alacritty
            # pyenv
            readline
            readline.dev
            zlib
            zlib.dev
            libffi
            libffi.dev
            openssl
            openssl.dev
            bzip2
            bzip2.dev
            lzma
            lzma.dev
            grpcurl
            sass
            niv
            jq
            yq
            tree
            btop
            zip
            pstree
            swig
            taplo
            # kubernetes
            kubernetes-helm
            k9s
            buildkit
            qemu
            direnv
            pplatex
            # postgres
            postgresql_14
            eksctl
            # languages
            go
            stylua
            selene
            nnn
            tmux
            asciinema
            cachix
            watch
            ripgrep
            # Need for IntelliJ to format code
            terraform
            # nvim related
            colima
            lima
            gitui
            lazygit
            kind
            any-nix-shell
            sqlite
            dtach
            earthly
            nixfmt-rfc-style
            enchant
            gitoxide
          ];

          shells = with pkgs; [ zsh ];

          # Setup environment variables to pass to zshrc
          variables = {
            GOPATH = "${builtins.getEnv "HOME"}/go";
            SQLITE_PATH = ''${pkgs.sqlite.out}/lib/libsqlite3.dylib'';
            PYENCHANT_LIBRARY_PATH = ''${pkgs.enchant.out}/lib/libenchant-2.2.dylib'';
            OPENBLAS = ''${pkgs.openblas.out}/lib/libopenblas.dylib'';
            PATH = "${pkgs.protobuf.out}/bin:$PATH";
          };
        };

        # Auto upgrade nix package and the daemon service.
        services.nix-daemon.enable = true;

        nix = {
          package = pkgs.nix;
          settings = {
            experimental-features = "nix-command flakes";
          };
        };

        # Networking
        networking = {
          knownNetworkServices = [ "Wi-Fi" ];
          dns = [
            "1.1.1.1"
            "8.8.8.8"
          ];
        };

        programs = {
          nix-index = { enable = true; };
          zsh = {
            enable = true;
            enableCompletion = true;
            enableBashCompletion = true;
            enableSyntaxHighlighting = true;
            promptInit = "autoload -Uz promptinit && promptinit";
          };
        };

        # add PAM
        security.pam.enableSudoTouchIdAuth = true;


        system = {
          # Set Git commit hash for darwin-version.
          configurationRevision = self.rev or self.dirtyRev or null;
          # Used for backwards compatibility, please read the changelog before changing.
          # $ darwin-rebuild changelog
          stateVersion = 4;
          defaults = {
            finder = {
              AppleShowAllFiles = true;
            };
          };
        };

        nixpkgs = {
          # The platform the configuration will be used on.
          hostPlatform = "aarch64-darwin";
          overlays = [ neovim-nightly-overlay.overlays.default ];
          config = {
            allowUnfree = true;
          };
        };
      };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake ".#aapl-mbp16-1692"
      darwinConfigurations."aapl-mbp16-1692" = nix-darwin.lib.darwinSystem {
        modules = [ configuration ];
      };

      # Expose the package set, including overlays, for convenience.
      darwinPackages = self.darwinConfigurations."aapl-mbp16-1692".pkgs;
    };
}
