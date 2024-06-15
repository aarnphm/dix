{
  config,
  pkgs,
  user,
  lib,
  ...
}: let
  homePath =
    if pkgs.stdenv.isDarwin
    then "/Users/${user}"
    else "/home/${user}";
  identityPaths = ["${homePath}/.pubkey.txt"];
  filterNone = values: builtins.filter (x: x != null) values;

  commonPackages = with pkgs; [
    # nix
    cachix

    # editor
    vim
    neovim
    zed-editor
    alacritty

    # kubernetes and container
    kubernetes-helm
    k9s
    buildkit
    qemu
    pplatex
    eksctl
    ratchet
    krew
    k9s
    lazydocker
    kind
    skopeo
    earthly
    buildifier

    # git
    git
    gitui
    lazygit
    git-lfs
    delta

    # languages
    go
    sass
    protobuf
    deno
    nodejs_20
    nodePackages_latest.pnpm
    pnpm-shell-completion
    rustup
    pyenv
    xz
    sshx
    awscli2
    age

    # tools for language, lsp, linter, etc.
    tree-sitter
    eclint
    nixfmt-rfc-style
    nixpkgs-fmt
    grpcurl
    taplo
    stylua
    selene
    buf
    protolint
    sqlite
    postgresql_14
    llvm_17
    openblas
    enchant

    # terminal
    any-nix-shell
    zsh-completions
    direnv
    tmux
    curl
    jq
    yq
    gh
    tree
    btop
    zip
    pstree
    eza
    zoxide
    rm-improved
    fd
    fzf
    bat
    sd
    ripgrep
    hexyl
    catimg
    tmux
    asciinema
    watch
    ffmpeg
    cmake
    dtach
    zstd
    gnused
    hyperfine
    gnupg
    gpg-tui
    gnumake
    agenix

    # dix packages overlays
    dix.bitwarden-cli
    dix.paperspace-cli
    dix.git-forest
    dix.unicopy

    # cuda
    cudatoolkit
    cudaPackages.tensorrt
    cudaPackages.cudnn
  ];
  darwinPackages = with pkgs; [
    # for some reason they don't have flock on darwin :(
    flock
    undmg
    xar
    cpio
    mas
    # apps
    pinentry_mac
    dix.pinentry-touchid
    dix.OrbStack
    dix.Splice
    dix.ZedPreview
  ];
  linuxPackages = with pkgs; [
    colima
    lima
    nvtopPackages.full
    pinentry-all
    coreutils-full # NOTE: on darwin we need to use Apple provided from xcrun
    llvmPackages.libcxxClang
  ];

  commonVariables = let
    inherit (pkgs) fd git neovim ripgrep zsh;
    inherit (lib) concatStringsSep getExe makeBinPath;
  in {
    # XDG
    XDG_BIN_HOME = "$HOME/.local/bin";

    # Bentoml
    BENTOML_HOME = "$HOME/.local/share/bentoml";
    BENTOML_DO_NOT_TRACK = "True";
    BENTOML_BUNDLE_LOCAL_BUILD = "True";
    OPENLLM_DEV_BUILD = "True";
    OPENLLM_DISABLE_WARNING = "False";

    # Editors
    WORKSPACE = "$HOME/workspace";
    SHELL = getExe zsh;
    EDITOR = getExe neovim;
    VISUAL = getExe neovim;
    MANPAGER = "${getExe neovim} +Man!";
    LSCOLORS = "ExFxBxDxCxegedabagacad";

    # Fzf
    FZF_CTRL_T_COMMAND = "${getExe fd} --hidden --follow --exclude .git";
    FZF_DEFAULT_COMMAND = let
      gitCheck = "${getExe git} rev-parse --is-inside-work-tree > /dev/null 2>&1";
      rgFiles = "${getExe ripgrep} --files --hidden";
    in "${gitCheck} && ${rgFiles} --ignore .git || ${rgFiles}";
    FZF_TMUX_HEIGHT = "70%";
    FZF_DEFAULT_OPTS_FILE = "$HOME/.fzfrc";

    # Language
    GOPATH = "${config.home.homeDirectory}/go";
    PYTHON3_HOST_PROG = getExe pkgs.python3-tools;
    NIX_INDEX_DATABASE = "$HOME/.cache/nix-index/";
    PATH = concatStringsSep ":" [
      (makeBinPath ["$HOME/.cargo" pkgs.protobuf])
      "$PATH"
    ];

    # Specifics to build
    NIX_INSTALLER_NIX_BUILD_USER_ID_BASE = "400";
  };
  darwinVariables = {
    # misc
    OPENBLAS = "${lib.makeLibraryPath [pkgs.openblas]}/libopenblas.dylib";
    SQLITE_PATH = "${lib.makeLibraryPath [pkgs.sqlite]}/libsqlite3.dylib";
    PYENCHANT_LIBRARY_PATH = "${lib.makeLibraryPath [pkgs.enchant]}/libenchant-2.2.dylib";
    LD_LIBRARY_PATH = with pkgs;
      lib.makeLibraryPath [
        (lib.getDev openssl)
        (lib.getDev zlib)
        (lib.getDev xz)
        (lib.getDev readline)
        stdenv.cc.cc.lib
        protobuf
        cairo
      ];
  };
  linuxVariables = {
    GPG_TTY = "$(tty)";
    CUDA_PATH = pkgs.cudatoolkit;
  };

  age' =
    {inherit identityPaths;}
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      secrets = {
        id_ed25519-github = {
          file = ./secrets/${user}-id_ed25519-github.age;
          path = "${homePath}/.ssh/id_ed25519-github";
          owner = user;
          mode = "700";
          group = "staff";
        };
        id_ed25519-paperspace = {
          file = ./secrets/${user}-id_ed25519-paperspace.age;
          path = "${homePath}/.ssh/id_ed25519-paperspace";
          owner = user;
          mode = "700";
          group = "staff";
        };
      };
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux
    {
      secrets = {
        id_ed25519-github = {
          file = ./secrets/${user}-id_ed25519-github.age;
          path = "${homePath}/.ssh/id_ed25519-github";
        };
      };
    };
in
  {age = age';}
  // lib.optionalAttrs pkgs.stdenv.isDarwin
  {
    environment = {
      variables = commonVariables // darwinVariables;
      systemPackages = filterNone (commonPackages ++ darwinPackages);
    };
  }
  // lib.optionalAttrs pkgs.stdenv.isLinux
  {
    home = {
      packages = filterNone (commonPackages ++ linuxPackages);
      sessionVariables = commonVariables // linuxVariables;
    };
  }
