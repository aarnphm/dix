{
  config,
  pkgs,
  lib,
  user,
  inputs,
  ...
}: let
  filterNone = value: builtins.filter (x: x != null) value;
  packages = with pkgs; [
    # nix
    # cachix

    # editor
    vim
    bun
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
    nodejs_22
    corepack_22
    rustup
    pyenv
    xz
    sshx
    awscli2
    age

    # tools for language, lsp, linter, etc.
    tree-sitter
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
    llvm_18
    openblas
    enchant

    # terminal
    any-nix-shell
    zsh-completions
    oh-my-posh
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
    watch
    ffmpeg
    dtach
    zstd
    gnused
    hyperfine
    gnupg
    gpg-tui
    gnumake
    alejandra

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
    dix.Splice
  ];
  linuxPackages = with pkgs; [
    colima
    lima
    nvtopPackages.full
    pinentry-all
    coreutils-full # NOTE: on darwin we need to use Apple provided from xcrun
    llvmPackages.libcxxClang
  ];

  sessionVariables = let
    inherit (pkgs) fd git neovim ripgrep zsh;
    inherit (lib) concatStringsSep getExe makeBinPath;
  in
    {
      # XDG
      XDG_BIN_HOME = "${config.home.homeDirectory}/.local/bin";

      # Bentoml
      BENTOML_HOME = "${config.home.sessionVariables.XDG_DATA_HOME}/bentoml";
      BENTOML_DO_NOT_TRACK = "True";
      BENTOML_BUNDLE_LOCAL_BUILD = "True";
      OPENLLM_DEV_BUILD = "True";
      OPENLLM_DISABLE_WARNING = "False";

      # Editors
      WORKSPACE = "${config.home.homeDirectory}/workspace";
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
      FZF_DEFAULT_OPTS_FILE = "${config.home.homeDirectory}/.fzfrc";

      # Language
      GOPATH = "${config.home.homeDirectory}/go";
      PYTHON3_HOST_PROG = getExe pkgs.python3-tools;
      PATH = concatStringsSep ":" [
        (makeBinPath ["${config.home.homeDirectory}/.cargo" pkgs.protobuf])
        "$PATH"
      ];

      # Specifics to build
      NIX_INSTALLER_NIX_BUILD_USER_ID_BASE = "400";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
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
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux
    {
      GPG_TTY = "$(tty)";
      CUDA_PATH = pkgs.cudatoolkit;
    };

  tomlFormat = pkgs.formats.toml {};

  gpgTuiConfig = {
    general = {
      detail_level = "full";
    };
    gpg = {
      armor = true;
    };
  };
in {
  imports = [
    ./modules
    # NOTE: since we are unifying everything under home manager
    # would need to homeManagerModules instead of darwinModules
    inputs.nix-index-database.hmModules.nix-index
  ];

  programs.home-manager.enable = true;
  programs.dircolors = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
  };

  alacritty.enable = true;
  awscli.enable = true;
  bat.enable = true;
  btop.enable = true;
  direnv.enable = true;
  git.enable = true;
  gpg.enable = true;
  ssh.enable = true;
  zsh.enable = true;
  zoxide.enable = true;

  # include neovim, vimrc, and oh-my-posh symlink
  xdg = {
    enable = true;
    configFile = {
      nvim = {
        source = config.lib.file.mkOutOfStoreSymlink "${pkgs.dix.editor}";
        recursive = true;
      };
      "gpg-tui/gpg-tui.toml".source = tomlFormat.generate "gpg-tui-config" gpgTuiConfig;
      "oh-my-posh/config.toml".source = ./modules/config/oh-my-posh/config.toml;
      "karabiner/karabiner.json".source = ./modules/config/karabiner/karabiner.json;
      "zed/keymap.json".source = ./modules/config/zed/keymap.json;
      "zed/settings.json".source = ./modules/config/zed/settings.json;
    };
  };
  editorconfig = {
    enable = true;
    settings = {
      "*" = {
        end_of_line = "lf";
        charset = "utf-8";
        trim_trailing_whitespace = true;
        indent_style = "space";
        indent_size = 2;
        max_line_width = 119;
      };
      "/node_modules/*" = {
        indent_size = "unset";
        indent_style = "unset";
      };
      "{package.json,.travis.yml,.eslintrc.json}" = {
        indent_style = "space";
      };
    };
  };

  home = {
    inherit sessionVariables;
    packages = filterNone (packages ++ (lib.optionals pkgs.stdenv.isDarwin darwinPackages) ++ (lib.optionals pkgs.stdenv.isLinux linuxPackages));
    username = user;
    homeDirectory = pkgs.lib.mkForce (
      if pkgs.stdenv.isLinux
      then "/home/${user}"
      else "/Users/${user}"
    );
    stateVersion = lib.trivial.release;

    file = let
      # rose-pine dawn
      # --color=fg:#797593,bg:#faf4ed,hl:#d7827e
      # --color=fg+:#575279,bg+:#f2e9e1,hl+:#d7827e
      # --color=border:#dfdad9,header:#286983,gutter:#faf4ed
      # --color=spinner:#ea9d34,info:#56949f,separator:#dfdad9
      # --color=pointer:#907aa9,marker:#b4637a,prompt:#797593
      fzfConfig = pkgs.writeText "fzfrc" ''
        --color=fg:#908caa,bg:#191724,hl:#ebbcba
        --color=fg+:#e0def4,bg+:#26233a,hl+:#ebbcba
        --color=border:#403d52,header:#31748f,gutter:#191724
        --color=spinner:#f6c177,info:#9ccfd8,separator:#403d52
        --color=pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa
        --bind='ctrl-/:toggle-preview'
        --bind='ctrl-u:preview-page-up'
        --bind='ctrl-d:preview-page-down'
        --preview-window 'right:40%:wrap'
        --cycle --bind 'tab:toggle-up,btab:toggle-down' --prompt='» ' --marker='»' --pointer='◆' --info=right --layout='reverse' --border='sharp' --preview-window='border-sharp' --height='80%'
      '';
    in
      {
        ".vimrc".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.dix.editor}/.vimrc";
        ".fzfrc".source = fzfConfig;
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        "/Library/Application Support/gpg-tui/gpg-tui.toml".source = tomlFormat.generate "gpg-tui-config" gpgTuiConfig;
      };

    # shells related
    shellAliases = {
      reload = "exec -l $SHELL";
      afk = "pmset displaysleepnow";
      ".." = "__zoxide_z ..";
      "..." = "..;..";
      "...." = "...;..";
      "....." = "....;..";
      "......" = ".....;..";

      # ls-replacement
      ls = "${lib.getExe pkgs.eza}";
      ll = "${lib.getExe pkgs.eza} -la --group-directories-first -snew --icons always";
      sudo = "nocorrect sudo";

      # safe rm
      rm = "${lib.getExe pkgs.rm-improved} --graveyard ${config.home.homeDirectory}/.local/share/Trash";

      # git
      g = "${lib.getExe pkgs.git}";
      ga = "${lib.getExe pkgs.git} add";
      gaa = "${lib.getExe pkgs.git} add .";
      gsw = "${lib.getExe pkgs.git} switch";
      gcm = "${lib.getExe pkgs.git} commit -S --signoff -sv";
      gcmm = "${lib.getExe pkgs.git} commit -S --signoff -svm";
      gcma = "${lib.getExe pkgs.git} commit -S --signoff -sv --amend";
      gcman = "${lib.getExe pkgs.git} commit -S --signoff -sv --amend --no-edit";
      grpo = "${lib.getExe pkgs.git} remote prune origin";
      grst = "${lib.getExe pkgs.git} restore";
      grsts = "${lib.getExe pkgs.git} restore --staged";
      gst = "${lib.getExe pkgs.git} status";
      gsi = "${lib.getExe pkgs.git} status --ignored";
      gsm = "${lib.getExe pkgs.git} status -sb";
      gfom = "${lib.getExe pkgs.git} fetch origin main";
      grfh = "${lib.getExe pkgs.git} rebase -i FETCH_HEAD";
      grb = "${lib.getExe pkgs.git} rebase -i -S --signoff";
      gra = "${lib.getExe pkgs.git} rebase --abort";
      grc = "${lib.getExe pkgs.git} rebase --continue";
      gri = "${lib.getExe pkgs.git} rebase -i";
      gcp = "${lib.getExe pkgs.git} cherry-pick --gpg-sign --signoff";
      gcpa = "${lib.getExe pkgs.git} cherry-pick --abort";
      gcpc = "${lib.getExe pkgs.git} cherry-pick --continue";
      gp = "${lib.getExe pkgs.git} pull";
      gpu = "${lib.getExe pkgs.git} push";
      gpuf = "${lib.getExe pkgs.git} push --force-with-lease";
      gs = "${lib.getExe pkgs.git} stash";
      gsp = "${lib.getExe pkgs.git} stash pop";
      gckb = "${lib.getExe pkgs.git} checkout -b";
      gck = "${lib.getExe pkgs.git} checkout";
      gdf = "${lib.getExe pkgs.git} diff";
      gb = "${lib.getExe pkgs.git} branches";
      gbd = "${lib.getExe pkgs.git} branch -D";
      gprc = "${lib.getExe pkgs.gh} pr create";

      # editor
      v = "${lib.getExe pkgs.neovim}";
      vi = "${lib.getExe pkgs.vim}";
      f = ''${lib.getExe pkgs.fd} --type f --hidden --exclude .git | ${lib.getExe pkgs.fzf} --preview "_fzf_complete_realpath {}" | xargs ${lib.getExe pkgs.neovim}'';

      # general
      cx = "chmod +x";
      freeport = "sudo fuser -k $@";
      copy = lib.getExe pkgs.dix.unicopy;

      # bentoml
      b = "bentoml";

      # useful
      bwpass = "[[ -f ${config.home.homeDirectory}/bw.master ]] && cat ${config.home.homeDirectory}/bw.master | sed -n 1p | ${lib.getExe pkgs.dix.unicopy}";
      unlock-vault = ''${lib.getExe pkgs.dix.bitwarden-cli} unlock --check &>/dev/null || export BW_SESSION=''${BW_SESSION:-"$(${lib.getExe pkgs.dix.bitwarden-cli} unlock --passwordenv BW_MASTER --raw)"}'';
      generate-password = "${lib.getExe pkgs.dix.bitwarden-cli} generate --special --uppercase --minSpecial 12 --length 80 | ${lib.getExe pkgs.dix.unicopy}";
      lock-workflow = ''${lib.getExe pkgs.fd} -Hg "*.yml" .github --exec-batch docker run --rm -v "''${PWD}":"''${PWD}" -w "''${PWD}" -e RATCHET_EXP_KEEP_NEWLINES=true ghcr.io/sethvargo/ratchet:0.9.2 update'';
      get-redirect = ''${lib.getExe pkgs.curl} -Ls -o /dev/null -w %{url_effective} $@'';
      get-gpg-password = ''${lib.getExe pkgs.dix.bitwarden-cli} get notes gpg-github-keys | ${lib.getExe pkgs.dix.unicopy}'';

      # nix-commands
      nrb =
        if pkgs.stdenv.isDarwin
        then ''darwin-rebuild switch --flake "$WORKSPACE/dix#appl-mbp16" -v --show-trace''
        else ''home-manager switch --flake "$WORKSPACE/dix#paperspace" --show-trace'';
      ned = ''
        ${lib.getExe pkgs.fd} --hidden --exclude .git --type f ${config.home.homeDirectory}/workspace/dix | FZF_DEFAULT_OPTS=$(__fzf_defaults ""  "--preview '_fzf_complete_realpath {}' +m ''${FZF_CTRL_F_OPTS-}") FZF_DEFAULT_OPTS_FILE="" __fzfcmd | xargs ${lib.getExe pkgs.neovim}
      '';
      nflp = "nix-env -qaP | grep $1";
      ncg = "nix-collect-garbage -d";
      nsp = "nix-shell --pure";
      nstr = "nix-store --gc --print-roots";

      # program opts
      cat = "${lib.getExe pkgs.bat}";
      # python
      pip = "uv pip";
      python3 = ''$(${lib.getExe pkgs.pyenv} root)/shims/python'';
      python-install = ''CPPFLAGS="-I${pkgs.zlib.outPath}/include -I${pkgs.xz.dev.outPath}/include" LDFLAGS="-L${lib.makeLibraryPath [pkgs.zlib pkgs.xz.dev]}" ${lib.getExe pkgs.pyenv} install "$@"'';
      ipynb = "jupyter notebook --autoreload --debug";
      ipy = "ipython";
      k = "kubectl";
      pinentry = lib.getExe (with pkgs; (
        if stdenv.isDarwin
        then pinentry_mac
        else pinentry-all
      ));
    };
  };
}
