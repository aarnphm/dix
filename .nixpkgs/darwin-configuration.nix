{ config, pkgs, lib, ... }:

let
  user = "aarnphm";

  go = pkgs.callPackage ./go.nix { };
  postgresql = pkgs.postgresql_14;
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
  awscli = awscli_v2_2_14.awscli2;
  # python related
  lightgbm = pkgs.python310Packages.lightgbm;
  pip = pkgs.python310Packages.pip;
in
{
  imports = [ <home-manager/nix-darwin> ];
  environment.variables = { EDITOR = "neovim"; };
  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  # nix-env -i /nix/store/ws2fbwf7xcmnhg2hlvq43qg22j06w5jb-niv-0.2.19-bin --option binary-caches https://cache.nixos.org
  environment.systemPackages = with pkgs; [
    vim
    tmux
    jdk
    jre
    openjdk17
    asciinema
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
    llvm
    ninja
    tree
    wget
    zip
    pstree
    bazel_5
    enchant
    vscode
    pkg-config
    swig
    openssl_3_0
    colima
    skopeo
    nnn
    gnused
    cachix
    ctags
    # kubernetes
    minikube
    kubernetes
    kubernetes-helm
    ngrok
    buildkit
    direnv
    postgresql
    # aws
    awscli
    # languages
    go
    stylua
    selene
    # python
    python310
    pip
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
    nerdfonts
    # ml stuff
    openblas
    protobuf
    # lightgbm
    cairo
  ];

  # Auto upgrade nix package and the daemon service.
  services.nix-daemon.enable = true;
  nix.package = pkgs.nix;

  # Create /etc/bashrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina
  nixpkgs.config.allowUnfree = true;

  users.users.${user}.home = "/Users/aarnphm";

  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url = https://github.com/nix-community/neovim-nightly-overlay/archive/master.tar.gz;
    }))
  ];

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    users.${user} = { pkgs, config, lib, ... }: {

      home.packages = with pkgs; [
        (pkgs.slack.overrideAttrs (oldAttrs: {
          installPhase = ''
            mkdir -p $out/Applications/Slack.app
            cp -R . $out/Applications/Slack.app
          '';
        }))
        ripgrep
        fd
        gopass
        coreutils
        watch
        ssm-session-manager-plugin
        lima
        k9s
        # Need for IntelliJ to format code
        terraform
        neovim-nightly
      ];

      programs.neovim.plugins = [
        {
          plugin = pkgs.vimPlugins.sqlite-lua;
          config = "let g:sqlite_clib_path = '${pkgs.sqlite.out}/lib/libsqlite3.dylib'";
        }
      ];
    };
  };


  environment.variables.SQLITE_PATH = ''${pkgs.sqlite.out}/lib/libsqlite3.dylib'';
  environment.variables.PYENCHANT_LIBRARY_PATH = ''${pkgs.enchant.out}/lib/libenchant-2.2.dylib'';
  environment.variables.OPENBLAS = ''${pkgs.openblas.out}/lib/libopenblas.dylib'';
  # LD_LIBRARY_PATH
  environment.variables.NIX_LD_LIBRARY_PATH = ''${pkgs.lib.makeLibraryPath [ pkgs.openssl pkgs.zlib pkgs.stdenv.cc.cc.lib pkgs.readline pkgs.lzma pkgs.protobuf pkgs.cairo ] }'';

  services.postgresql.enable = true;
  services.postgresql.package = postgresql;
  services.postgresql.dataDir = "/data/postgresql";

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
}
