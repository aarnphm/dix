{ pkgs, lib, ... }:
let
  defaultEnv =
    let
      inherit (pkgs) fd git neovim ripgrep zsh;
      inherit (lib) concatStringsSep getExe makeBinPath;
    in
    {
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
      FZF_DEFAULT_COMMAND =
        let
          gitCheck = "${getExe git} rev-parse --is-inside-work-tree > /dev/null 2>&1";
          rgFiles = "${getExe ripgrep} --files --hidden";
        in
        "${gitCheck} && ${rgFiles} --ignore .git || ${rgFiles}";
      FZF_TMUX_HEIGHT = "70%";
      FZF_DEFAULT_OPTS_FILE = "$HOME/.fzfrc";

      # Language
      GOPATH = "$HOME/go";
      PYTHON3_HOST_PROG = getExe pkgs.python3-tools;
      NIX_INDEX_DATABASE = "$HOME/.cache/nix-index/";
      PATH = concatStringsSep ":" [
        (makeBinPath [ "$HOME/.cargo" pkgs.protobuf ])
        "$PATH"
      ];

      # Specifics to build
      NIX_INSTALLER_NIX_BUILD_USER_ID_BASE = "400";
    };

  linuxEnv = {
    GPG_TTY = "$(tty)";
    CUDA_PATH = pkgs.cudatoolkit;
  };

  darwinEnv = {
    # misc
    OPENBLAS = "${lib.makeLibraryPath [pkgs.openblas]}/libopenblas.dylib";
    SQLITE_PATH = "${lib.makeLibraryPath [pkgs.sqlite]}/libsqlite3.dylib";
    PYENCHANT_LIBRARY_PATH = "${lib.makeLibraryPath [pkgs.enchant]}/libenchant-2.2.dylib";
    LD_LIBRARY_PATH = with pkgs; lib.makeLibraryPath [
      (lib.getDev openssl)
      (lib.getDev zlib)
      (lib.getDev xz)
      (lib.getDev readline)
      stdenv.cc.cc.lib
      protobuf
      cairo
    ];
  };

in
defaultEnv // (lib.optionalAttrs pkgs.stdenv.isLinux linuxEnv) // (lib.optionalAttrs pkgs.stdenv.isDarwin darwinEnv)
