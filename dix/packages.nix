{ pkgs, lib, ... }:
let
  common = with pkgs; [
    # nix
    cachix

    # editor
    vim
    neovim
    alacritty

    # kubernetes and container
    kubernetes-helm
    k9s
    buildkit
    qemu
    pplatex
    eksctl
    colima
    lima
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

  darwin = with pkgs; [
    # for some reason they don't have flock on darwin :(
    flock
    pinentry_mac
    dix.pinentry-touchid

    # Specific Application built
    dix.OrbStack
    dix.Rectangle
    dix.Discord
  ];

  linux = with pkgs; [
    pinentry-all
    coreutils-full # NOTE: on darwin we need to use Apple provided from xcrun
    llvmPackages.libcxxClang
  ];

in
(builtins.filter (x: x != null) common) ++ lib.optionals pkgs.stdenv.isDarwin darwin ++ lib.optionals pkgs.stdenv.isLinux linux
