{ config, pkgs, lib, ... }:

let
  inherit (pkgs) callPackage fetchFromGitHub;
  inherit (builtins) fetchTarball;

  username = "aarnphm";
  homeDir = builtins.getEnv "HOME";

  go = pkgs.callPackage ./language/go/go.nix { };
  pyenv-variables = {

    CPPFLAGS = "-I$(xcrun --show-sdk-path)/usr/include -I${pkgs.protobuf.out}/include -I${pkgs.xz.dev}/include -I${pkgs.zlib.dev}/include -I${pkgs.libffi.dev}/include -I${pkgs.readline.dev}/include -I${pkgs.bzip2.dev}/include -I${pkgs.openssl.dev}/include";
    CFLAGS = "-I${pkgs.openssl.dev}/include";
    LDFLAGS = "-L${pkgs.zlib.dev}/lib -L${pkgs.libffi.dev}/lib -L${pkgs.readline.dev}/lib -L${pkgs.bzip2.dev}/lib -L${pkgs.openssl.dev}/lib -L${pkgs.xz.dev}/lib";
    PYENV_ROOT = "${homeDir}/.pyenv";
    PYENV_VIRTUALENV_DISABLE_PROMPT = "1"; # supress annoying warning for a feature I don't use
  };

  awscli_v2_2_14 = import
    (fetchTarball {
      name = "awscli_v2_2_14";
      url = "https://github.com/nixos/nixpkgs/archive/aab3c48aef2260867272bf6797a980e32ccedbe0.tar.gz";
      # Hash obtained using `nix-prefetch-url --unpack <url>`
      sha256 = "0mhihlpmizn7dhcd8pjj9wvb13fxgx4qqr24qgq79w1rhxzzk6mv";
    })
    { };

  protobuf = fetchFromGitHub {
    owner = "protocolbuffers";
    repo = "protobuf";
    rev = "13c8a056f9c9cc2823608f6cbd239dcb8b9f11e5";
    # Hash obtained using `nix-prefetch-url --unpack <url>`
    sha256 = "1nkkb2lw3ci7hqsrrn7f3saa43m3s6cjvcqsdkwjbz4mrns0bg2m";
  };
in
{
  imports = [ ./common/security.nix ];
  # imports TouchID features
  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;
  security.pam.enablePamTouchIdAuth = true;

  users.users.${username} = {
    home = "/Users/${username}";
    name = username;
  };

  # auto gc
  nix = {
    gc = {
      automatic = true;
      options = "--max-freed $((25 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";
    };
    package = pkgs.nixUnstable;

    # enable flake and experimental command
    extraOptions = ''
      auto-optimise-store = true
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '' + lib.optionalString (pkgs.system == "aarch64-darwin") ''
      extra-platforms = x86_64-darwin aarch64-darwin
    '';
  };

  # enable zsh by default
  programs.nix-index.enable = true;
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableBashCompletion = true;
    enableFzfHistory = true;
    enableSyntaxHighlighting = true;
    promptInit = "autoload -Uz promptinit && promptinit";
  };

  nixpkgs = {
    overlays = [
      # add neovim overloay
      (import (builtins.fetchTarball {
        url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
      }))
      (self: super: {
        # https://github.com/nmattia/niv/issues/332#issuecomment-958449218
        # TODO: remove this when upstream is fixed.
        niv =
          self.haskell.lib.compose.overrideCabal
            (drv: { enableSeparateBinOutput = false; })
            super.haskellPackages.niv;
        python-appl-m1 = super.buildEnv {
          name = "python-appl-m1";
          paths = [
            # A Python 3 interpreter with some packages
            (self.python310.withPackages (ps: with ps; [ pynvim pip virtualenv pipx ]))
          ];
        };
      })
    ];
    config = {
      allowUnfree = true;
      allowBroken = true;
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

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  # nix-env -i /nix/store/ws2fbwf7xcmnhg2hlvq43qg22j06w5jb-niv-0.2.19-bin --option binary-caches https://cache.nixos.org
  environment = {
    systemPackages = with pkgs; [
      # emulator
      alacritty
      # editor
      vim
      neovim-nightly
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
      autoconf
      openjdk
      # development
      terminal-notifier
      grpcurl
      sass
      niv
      ccls
      fd
      fzf
      git
      gh
      ghq
      hub
      gnupg
      perl
      jq
      yq
      ninja
      tree
      btop
      wget
      zip
      pstree
      bazel_5
      swig
      colima
      gnused
      ctags
      llvmPackages_13.llvm
      # kubernetes
      skopeo
      minikube
      kubernetes-helm
      ngrok
      k9s
      buildkit
      podman
      qemu
      direnv
      # postgres
      postgresql_14
      # aws
      awscli_v2_2_14.awscli2
      eksctl
      # languages
      go
      stylua
      selene
      coreutils
      nnn
      tmux
      asciinema
      cachix
      watch
      ripgrep
      lima
      # Need for IntelliJ to format code
      terraform
      # nvim related
      code-minimap
      tree-sitter
      gitui
      any-nix-shell
      sqlite
      dtach
      cairo
      earthly
      rnix-lsp
      # python
      python-appl-m1
      enchant
      # ml stuff
      openblas
      protobuf
    ];

    # add shell installed by nix to /etc/shells
    shells = with pkgs; [
      zsh
    ];

    # Setup environment variables to pass to zshrc
    variables = {
      JAVA_HOME = "${pkgs.openjdk11}";
      GOPATH = "${homeDir}/go";
      PYTHON3_HOST_PROG = ''${pkgs.python-appl-m1}/bin/python3.10'';
      EDITOR = ''${pkgs.neovim-nightly}/bin/nvim'';
      SQLITE_PATH = ''${pkgs.sqlite.out}/lib/libsqlite3.dylib'';
      PYENCHANT_LIBRARY_PATH = ''${pkgs.enchant.out}/lib/libenchant-2.2.dylib'';
      OPENBLAS = ''${pkgs.openblas.out}/lib/libopenblas.dylib'';
      LD_LIBRARY_PATH = ''${lib.makeLibraryPath [ pkgs.openssl.out pkgs.zlib.out pkgs.stdenv.cc.cc.lib pkgs.readline.out pkgs.protobuf.out pkgs.cairo.out ] }:/usr/lib32:/usr/lib:${homeDir}/.local/lib'';
      PATH = "${pkgs.protobuf.out}/bin:$PATH";
    } // pyenv-variables;
  };

  # TODO: remove applications.text once https://github.com/LnL7/nix-darwin/issues/485 is resolved
  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" ]; })
    ];
  };

  services = {
    # Auto upgrade nix package and the daemon service.
    nix-daemon.enable = true;

    postgresql = {
      enable = true;
      package = pkgs.postgresql_14;
      dataDir = "/data/postgresql";
    };
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system = {
    stateVersion = 4;
    activationScripts = {
      # Disable fontrestore until it is fixed on Ventura
      fonts.text = lib.mkForce ''
        # Set up fonts.
        echo "configuring fonts..." >&2
        find -L "$systemConfig/Library/Fonts" -type f -print0 | while IFS= read -rd "" l; do
            font=''${l##*/}
            f=$(readlink -f "$l")
            if [ ! -e "/Library/Fonts/$font" ]; then
                echo "updating font $font..." >&2
                ln -fn -- "$f" /Library/Fonts 2>/dev/null || {
                  echo "Could not create hard link. Nix is probably on another filesystem. Copying the font instead..." >&2
                  rsync -az --inplace "$f" /Library/Fonts
                }
            fi
        done
      '';
    };
  };
}
