{ config, pkgs, lib, ... }:

let
  inherit (pkgs) callPackage fetchFromGitHub;

  username = "aarnphm";
  homeDir = builtins.getEnv "HOME";

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

  documentation.enable = false;

  # auto gc
  nix = {
    gc = {
      automatic = true;
      options = "--max-freed $((25 * 1024**3 - 1024 * $(df -P -k /nix/store | tail -n 1 | awk '{ print $4 }')))";
    };
    package = pkgs.nixUnstable;

    # enable flake and experimental command
    extraOptions = ''
      auto-optimise-store = false
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-failed = false
      keep-derivations = true
      trusted-users = root ${username}
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
      # editor
      vim
      # XXX: currently neovim-nightly is broken, use neovim --HEAD from brew
      neovim-nightly
      buf
      protolint
      eclint
      # alacritty
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
      ngrok
      k9s
      buildkit
      qemu
      direnv
      pplatex
      # postgres
      postgresql_14
      # aws
      awscli_v2_2_14.awscli2
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
      nixfmt
      # python
      python-appl-m1
      enchant
      gitoxide
    ];

    # add shell installed by nix to /etc/shells
    shells = with pkgs; [
      zsh
    ];

    # Setup environment variables to pass to zshrc
    variables = {
      GOPATH = "${homeDir}/go";
      PYTHON3_HOST_PROG = ''${pkgs.python-appl-m1}/bin/python3.10'';
      SQLITE_PATH = ''${pkgs.sqlite.out}/lib/libsqlite3.dylib'';
      PYENCHANT_LIBRARY_PATH = ''${pkgs.enchant.out}/lib/libenchant-2.2.dylib'';
      OPENBLAS = ''${pkgs.openblas.out}/lib/libopenblas.dylib'';
      PATH = "${pkgs.protobuf.out}/bin:$PATH";
    };
  };

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
}
