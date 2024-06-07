{ pkgs, lib, ... }:
with lib;
let
  ld_path = makeLibraryPath [
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
  XDG_BIN_HOME = "$HOME/.local/bin";

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
  SIMPLE_BACKGROUND = "dark";
  # fzf
  FZF_CTRL_T_COMMAND = ''${pkgs.fd.out}/bin/fd --hidden --follow --exclude .git'';
  FZF_DEFAULT_COMMAND = ''${pkgs.ripgrep.out}/bin/rg --files --no-ignore-vcs --hidden'';
  FZF_DEFAULT_OPTS_FILE = "$HOME/.fzfrc";
  # language
  GOPATH = "$HOME/go";
  PYTHON3_HOST_PROG = ''${pkgs.python3-tools}/bin/python'';
  NIX_INDEX_DATABASE = "$HOME/.cache/nix-index/";
  # misc
  OPENBLAS = ''${pkgs.openblas}/lib/libopenblas.dylib'';
  SQLITE_PATH = ''${pkgs.sqlite}/lib/libsqlite3.dylib'';
  PYENCHANT_LIBRARY_PATH = ''${pkgs.enchant}/lib/libenchant-2.2.dylib'';
  PATH = lib.concatStringsSep ":" [ "${lib.makeBinPath [ pkgs.protobuf pkgs.skhd "$PAPERSPACE_INSTALL" ]}" "$PATH" ];
  LD_LIBRARY_PATH = ld_path;
}
