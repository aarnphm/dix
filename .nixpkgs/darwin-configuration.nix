{ config, pkgs, lib, ... }:

let
  user = "aarnphm";

  go = pkgs.callPackage ./language/go/go.nix { };

  awscli_v2_2_14 = import
    (builtins.fetchTarball {
      name = "awscli_v2_2_14";
      url = "https://github.com/nixos/nixpkgs/archive/aab3c48aef2260867272bf6797a980e32ccedbe0.tar.gz";
      # Hash obtained using `nix-prefetch-url --unpack <url>`
      sha256 = "0mhihlpmizn7dhcd8pjj9wvb13fxgx4qqr24qgq79w1rhxzzk6mv";
    })
    { };

  protobuf = pkgs.fetchFromGitHub {
    owner = "protocolbuffers";
    repo = "protobuf";
    rev = "13c8a056f9c9cc2823608f6cbd239dcb8b9f11e5";
    sha256 = "1nkkb2lw3ci7hqsrrn7f3saa43m3s6cjvcqsdkwjbz4mrns0bg2m";
  };

  # python related
  pip = pkgs.python310Packages.pip;
  postgresql = pkgs.postgresql_14;
in
{
  imports = [ ./common/security/touch.nix ];

  # Add ability to used TouchID for sudo authentication
  security.pam.enableSudoTouchIdAuth = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  users.users.${user}.home = "/Users/aarnphm";

  # auto gc
  nix = {
    gc = {
      automatic = true;
      options = "--max-freed $((25 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";
    };
    package = pkgs.nix;

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

  nixpkgs = {
    overlays = [
      # add neovim overloay
      (import (builtins.fetchTarball {
        url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
      }))
    ];
    config = {
      allowUnfree = true;
    };
  };

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  # nix-env -i /nix/store/ws2fbwf7xcmnhg2hlvq43qg22j06w5jb-niv-0.2.19-bin --option binary-caches https://cache.nixos.org
  environment = {
    systemPackages = with pkgs; [
      # emulator
      alacritty
      kitty
      # editor
      vim
      neovim-nightly
      # development
      jre
      openjdk17
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
      lzma
      readline
      zlib
      ninja
      tree
      m-cli
      wget
      zip
      pstree
      bazel_5
      vscode
      swig
      openssl_3_0
      colima
      skopeo
      gnused
      ctags
      # kubernetes
      minikube
      kubernetes
      kubernetes-helm
      ngrok
      k9s
      buildkit
      direnv
      postgresql
      # aws
      awscli_v2_2_14.awscli2
      eksctl
      # languages
      go
      stylua
      selene
      python310
      pip
      llvmPackages_latest.llvm
      coreutils
      nnn
      tmux
      asciinema
      cachix
      watch
      ripgrep
      ssm-session-manager-plugin
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
      pip
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
    variables = with pkgs; {
      EDITOR = ''${neovim-nightly}/bin/nvim'';
      SQLITE_PATH = ''${sqlite.out}/lib/libsqlite3.dylib'';
      PYENCHANT_LIBRARY_PATH = ''${enchant.out}/lib/libenchant-2.2.dylib'';
      OPENBLAS = ''${openblas.out}/lib/libopenblas.dylib'';

      # LD_LIBRARY_PATH
      CPLUS_INCLUDE_PATH = ''${lzma.dev}/include'';
      NIX_LD_LIBRARY_PATH = ''${lib.makeLibraryPath [ openssl zlib stdenv.cc.cc.lib readline lzma.dev protobuf cairo ] }'';
    };

  };

  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      recursive
      (nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
    ];

  };

  services = {

    # Auto upgrade nix package and the daemon service.
    nix-daemon.enable = true;

    postgresql = {
      enable = true;
      package = postgresql;
      dataDir = "/data/postgresql";
    };
  };
}
