{ pkgs, lib, ... }:
with pkgs; [
  # nix
  cachix

  # editor
  vim
  neovim-developer
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
  zsh-f-sy-h
  zsh-history-substring-search

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
  eza # exa-maintained fork
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
  (if stdenv.isDarwin then pinentry_mac else pinentry-all)
] ++ (
  with pkgs.dix; [
    bitwarden-cli
    paperspace-cli
    git-forest
  ] ++ lib.optionals (pkgs.stdenv.isDarwin) [
    # Applications
    OrbStack
    Rectangle
    # Bitwarden
    Discord

    # gpg
    pinentry-touchid
  ]
)
