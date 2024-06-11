{ pkgs, lib, ... }:
lib.mkMerge [
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
    SHELL = "${lib.getExe pkgs.zsh}";
    EDITOR = "${lib.getExe pkgs.neovim}";
    VISUAL = "${lib.getExe pkgs.neovim}";
    MANPAGER = "${lib.getExe pkgs.neovim} +Man!";
    LSCOLORS = "ExFxBxDxCxegedabagacad";
    SIMPLE_BACKGROUND = "dark";
    # fzf
    FZF_CTRL_T_COMMAND = ''${lib.getExe pkgs.fd} --hidden --follow --exclude .git'';
    FZF_DEFAULT_COMMAND = ''${lib.getExe pkgs.ripgrep} --files --hidden --ignore .git'';
    FZF_TMUX_HEIGHT = "80%";
    FZF_DEFAULT_OPTS_FILE = "$HOME/.fzfrc";
    # language
    GOPATH = "$HOME/go";
    PYTHON3_HOST_PROG = ''${lib.getExe pkgs.python3-tools}'';
    NIX_INDEX_DATABASE = "$HOME/.cache/nix-index/";
    PATH = lib.concatStringsSep ":" [ "${lib.makeBinPath [ "$HOME/.cargo" pkgs.protobuf ] }" "$PATH" ];
    LD_LIBRARY_PATH = with pkgs; lib.makeLibraryPath [
      (lib.getDev openssl)
      (lib.getDev zlib)
      (lib.getDev xz)
      (lib.getDev readline)
      stdenv.cc.cc.lib
      protobuf
      cairo
    ];
  }
  (
    if pkgs.stdenv.isLinux then
      {
        GPG_TTY = "$(tty)";
      } else { }
  )
  (
    if pkgs.stdenv.isDarwin then
      {
        # misc
        OPENBLAS = ''${lib.makeLibraryPath [pkgs.openblas]}/libopenblas.dylib'';
        SQLITE_PATH = ''${lib.makeLibraryPath [pkgs.sqlite]}/libsqlite3.dylib'';
        PYENCHANT_LIBRARY_PATH = ''${pkgs.enchant}/lib/libenchant-2.2.dylib'';
      }
    else { }
  )
]
