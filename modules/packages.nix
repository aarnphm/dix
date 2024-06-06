{ pkgs, ... }:
with pkgs; [
  # nix
  cachix

  # editor
  vim
  neovim-developer
  alacritty

  # kubernetes
  kubernetes-helm
  k9s
  buildkit
  qemu
  pplatex
  eksctl
  colima
  lima
  krew
  k9s
  lazydocker
  kind
  skopeo
  earthly

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
  nodejs_20
  nodePackages_latest.pnpm
  pnpm-shell-completion
  rustup
  pyenv
  xz
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
  ripgrep
  tmux
  asciinema
  watch
  ffmpeg
  cmake
  dtach
  zstd
  gnused
  gnupg
  hyperfine
]
