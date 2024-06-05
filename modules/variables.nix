{ pkgs, lib, ... }:
let
  ld_path = lib.makeLibraryPath [
    pkgs.openssl.dev
    pkgs.zlib.dev
    pkgs.xz.dev
    pkgs.stdenv.cc.cc.lib
    pkgs.readline.dev
    pkgs.protobuf
    pkgs.cairo
  ];
in
{
  # xdg
  XDG_CONFIG_HOME = "$HOME/.config";
  XDG_DATA_HOME = "$HOME/.local/share";
  XDG_BIN_HOME = "$HOME/.local/bin";
  XDG_CACHE_HOME = "$HOME/.cache";

  # bentoml
  BENTOML_HOME = "$HOME/.local/share/bentoml";
  BENTOML_DO_NOT_TRACK = "True";
  BENTOML_BUNDLE_LOCAL_BUILD = "True";
  OPENLLM_DEV_BUILD = "True";
  OPENLLM_DISABLE_WARNING = "False";

  # editors
  WORKSPACE = "$HOME/workspace";
  SHELL = "${pkgs.zsh}/bin/zsh";
  EDITOR = "${pkgs.neovim-developer}/bin/nvim";
  VISUAL = "${pkgs.neovim-developer}/bin/nvim";
  MANPAGER = "${pkgs.neovim-developer}/bin/nvim +Man!";
  LSCOLORS = "ExFxBxDxCxegedabagacad";
  TERM = "xterm-256color";
  # fzf
  FZF_DEFAULT_OPTS = ''--no-mouse --bind "?:toggle-preview,ctrl-a:select-all,ctrl-d:preview-page-down,ctrl-u:preview-page-up"'';
  FZF_CTRL_T_COMMAND = ''${pkgs.fd.out}/bin/fd --hidden --follow --exclude .git'';
  # language
  GOPATH = "$HOME/go";
  PYTHON3_HOST_PROG = ''${pkgs.python3-tools}/bin/python'';
  NIX_INDEX_DATABASE = "$HOME/.cache/nix-index/";
  # misc
  PAPERSPACE_INSTALL = "$HOME/.paperspace";
  OPENBLAS = ''${pkgs.openblas}/lib/libopenblas.dylib'';
  SQLITE_PATH = ''${pkgs.sqlite}/lib/libsqlite3.dylib'';
  PYENCHANT_LIBRARY_PATH = ''${pkgs.enchant}/lib/libenchant-2.2.dylib'';
  PATH = lib.concatStringsSep ":" [ "${lib.makeBinPath [ pkgs.protobuf pkgs.skhd "$PAPERSPACE_INSTALL" ]}" "$PATH" ];
  LD_LIBRARY_PATH = ld_path;
}
