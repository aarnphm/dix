{ pkgs, lib, ... }:
with lib;
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
  SHELL = "${getExe pkgs.zsh}";
  EDITOR = "${getExe pkgs.neovim-developer}";
  VISUAL = "${getExe pkgs.neovim-developer}";
  MANPAGER = "${getExe pkgs.neovim-developer} +Man!";
  LSCOLORS = "ExFxBxDxCxegedabagacad";
  SIMPLE_BACKGROUND = "dark";
  # fzf
  FZF_CTRL_T_COMMAND = ''${getExe pkgs.fd} --hidden --follow --exclude .git'';
  FZF_DEFAULT_COMMAND = ''${getExe pkgs.ripgrep} --files --hidden --ignore .git'';
  FZF_TMUX_HEIGHT = "80%";
  FZF_DEFAULT_OPTS_FILE = "$HOME/.fzfrc";
  # language
  GOPATH = "$HOME/go";
  PYTHON3_HOST_PROG = ''${getExe pkgs.python3-tools}'';
  NIX_INDEX_DATABASE = "$HOME/.cache/nix-index/";
  # misc
  OPENBLAS = ''${pkgs.openblas}/lib/libopenblas.dylib'';
  SQLITE_PATH = ''${pkgs.sqlite}/lib/libsqlite3.dylib'';
  PYENCHANT_LIBRARY_PATH = ''${pkgs.enchant}/lib/libenchant-2.2.dylib'';
  PATH = lib.concatStringsSep ":" [ "${lib.makeBinPath [ pkgs.protobuf ] }" "$PATH" ];
  LD_LIBRARY_PATH = with pkgs; makeLibraryPath [
    (getDev openssl)
    (getDev zlib)
    (getDev xz)
    (getDev readline)
    stdenv.cc.cc.lib
    protobuf
    cairo
  ];
}
