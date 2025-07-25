{
  config,
  pkgs,
  lib,
  user,
  ...
}: let
  filterNone = value: builtins.filter (x: x != null) value;
  packages = with pkgs; [
    # editor
    vim
    gvim
    bun
    uv
    ty
    fh

    # kubernetes and container
    kubernetes-helm
    kubectl
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
    awscli2
    atuin
    nodejs_24

    # git
    git
    gitui
    lazygit
    git-lfs
    delta

    # languages
    go
    protobuf
    pnpm
    zulu17
    xz
    age

    # tools for language, lsp, linter, etc.
    tree-sitter
    grpcurl
    taplo
    stylua
    selene
    protolint
    buf
    sqlite
    postgresql_14
    llvm_18
    openblas
    enchant
    python313Packages.pylatexenc
    pastel

    # terminal
    any-nix-shell
    zsh-completions
    oh-my-posh
    direnv
    curl
    jq
    yq-go
    gh
    btop
    zip
    pstree
    eza
    zoxide
    rm-improved
    mmv
    fd
    dust
    duf
    broot
    fzf
    bat
    sd
    procs
    xh
    mupdf
    ripgrep
    hexyl
    catimg
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
    ueberzugpp
    google-cloud-sdk
    bitwarden-cli

    # packages overlays
    git-forest
    unicopy
    lambda
    nebius
  ];
  darwinPackages = with pkgs; [
    # for some reason they don't have flock on darwin :(
    flock
    undmg
    xar
    rustup
    cpio
    mas
    mactop
    imagemagick
    # texliveFull
    mermaid-cli
    ghostscript
    # apps
    pinentry_mac
    pinentry-touchid
  ];
  linuxPackages = with pkgs; [
    colima
    lima
    pinentry-all
    # NOTE: on darwin we need to use Apple provided from xcrun
    coreutils-full
  ];

  sessionVariables = let
    inherit (pkgs) fd git neovim ripgrep zsh;
    inherit (lib) concatStringsSep getExe makeBinPath;
  in
    {
      # custom envvar to control theme from one spot
      XDG_SYSTEM_THEME = "light"; # dark

      # XDG
      XDG_BIN_HOME = "${config.home.homeDirectory}/.local/bin";

      # bentoml
      BENTOML_HOME = "${config.home.sessionVariables.XDG_DATA_HOME}/bentoml";
      BENTOML_DO_NOT_TRACK = "True";
      BENTOML_BUNDLE_LOCAL_BUILD = "True";

      UV_NO_PROGRESS = 1;

      # Editors
      WORKSPACE = "${config.home.homeDirectory}/workspace";
      SHELL = getExe zsh;
      VISUAL = getExe neovim;
      MANPAGER = "${getExe neovim} +Man!";

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
      PATH = concatStringsSep ":" [
        (makeBinPath ["${config.home.homeDirectory}/.cargo" pkgs.protobuf "${config.home.homeDirectory}/.local" "/opt/homebrew/opt/ruby"])
        "$PATH"
      ];
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      # misc
      OPENBLAS = "${lib.makeLibraryPath [pkgs.openblas]}/libopenblas.dylib";
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux
    {
      GPG_TTY = "$(tty)";
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
  imports = [./modules];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = false;
    enableBashIntegration = true;
  };

  alacritty.enable = true;
  bat.enable = true;
  broot.enable = true;
  btop.enable = true;
  direnv.enable = true;
  git.enable = true;
  ghostty.enable = true;
  gpg.enable = true;
  ssh.enable = true;
  zsh.enable = true;
  atuin.enable = true;
  zoxide.enable = true;
  neovim.enable = true;

  # include neovim, vimrc, and oh-my-posh symlink
  xdg = {
    enable = true;
    configFile = {
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
      colorMapping = {
        "rose-pine" = {
          light = {
            default = ''--color=fg:#797593,bg:#faf4ed,hl:#d7827e --color=fg+:#575279,bg+:#f2e9e1,hl+:#d7827e --color=border:#dfdad9,header:#286983,gutter:#faf4ed --color=spinner:#ea9d34,info:#56949f --color=pointer:#907aa9,marker:#b4637a,prompt:#797593'';
          };
          dark = {
            default = ''--color=fg:#908caa,bg:#191724,hl:#ebbcba --color=fg+:#e0def4,bg+:#26233a,hl+:#ebbcba --color=border:#403d52,header:#31748f,gutter:#191724 --color=spinner:#f6c177,info:#9ccfd8 --color=pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa'';
            moon = ''--color=fg:#908caa,bg:#232136,hl:#ea9a97 --color=fg+:#e0def4,bg+:#393552,hl+:#ea9a97 --color=border:#44415a,header:#3e8fb0,gutter:#232136 --color=spinner:#f6c177,info:#9ccfd8 --color=pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa'';
          };
        };
        "flexoki" = {
          light = {
            default = ''--color=fg:#B7B5AC,bg:#FFFCF0,hl:#100F0F --color=fg+:#B7B5AC,bg+:#F2F0E5,hl+:#100F0F --color=border:#AF3029,header:#100F0F,gutter:#FFFCF0 --color=spinner:#3AA99F,info:#3AA99F,separator:#F2F0E5 --color=pointer:#D0A215,marker:#D14D41,prompt:#D0A215'';
          };
          dark = {
            default = ''--color=fg:#878580,bg:#100F0F,hl:#CECDC3 --color=fg+:#878580,bg+:#1C1B1A,hl+:#CECDC3 --color=border:#AF3029,header:#CECDC3,gutter:#100F0F --color=spinner:#24837B,info:#24837B,separator:#1C1B1A --color=pointer:#AD8301,marker:#AF3029,prompt:#AD8301'';
          };
        };
      };
      variants = "default";

      fzfConfig = pkgs.writeText "fzfrc" (pkgs.concatStringsSepNewLine [
        colorMapping.flexoki.${config.home.sessionVariables.XDG_SYSTEM_THEME}.${variants}
        ''
          --bind='ctrl-/:toggle-preview'
          --bind='ctrl-u:preview-page-up'
          --bind='ctrl-d:preview-page-down'
          --preview-window 'right:40%:wrap'
          --cycle --bind 'tab:toggle-up,btab:toggle-down' --prompt='» ' --marker='»' --pointer='◆' --info=right --layout='reverse' --border='sharp' --preview-window='border-sharp' --height='80%'
        ''
      ]);
    in
      {
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
      ls = lib.getExe pkgs.eza;
      ll = "${lib.getExe pkgs.eza} -Ml --almost-all --group-directories-first -sName --icons=always";
      mtree = "${lib.getExe pkgs.eza} --almost-all -Ml --group-directories-first --tree";
      sudo = "nocorrect sudo";
      tree = ''${lib.getExe pkgs.broot} $@'';

      # safe rm
      rm = "${lib.getExe pkgs.rm-improved} --graveyard ${config.home.homeDirectory}/.local/share/Trash";

      # git
      g = lib.getExe pkgs.git;
      gcl = "${lib.getExe pkgs.gh} repo clone";
      ga = "${lib.getExe pkgs.git} add";
      gaa = "${lib.getExe pkgs.git} add .";
      gsw = "${lib.getExe pkgs.git} switch";
      gcm = "${lib.getExe pkgs.git} commit -S --signoff -sv";
      gcmm = "${lib.getExe pkgs.git} commit -S --signoff -svm";
      gcma = "${lib.getExe pkgs.git} commit -S --signoff -sv --amend";
      gcman = "${lib.getExe pkgs.git} commit -S --signoff -sv --amend --no-edit";
      grpo = "${lib.getExe pkgs.git} remote prune origin";
      grpu = "${lib.getExe pkgs.git} remote prune upstream";
      grst = "${lib.getExe pkgs.git} restore";
      grsts = "${lib.getExe pkgs.git} restore --staged";
      gst = "${lib.getExe pkgs.git} status";
      gsi = "${lib.getExe pkgs.git} status --ignored";
      gsm = "${lib.getExe pkgs.git} status -sb";
      gfom = "${lib.getExe pkgs.git} fetch origin main";
      gfum = "${lib.getExe pkgs.git} fetch upstream main";
      grfh = "${lib.getExe pkgs.git} rebase FETCH_HEAD --autosquash --ff";
      grifh = "${lib.getExe pkgs.git} rebase -i FETCH_HEAD --autosquash";
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
      gsts = "${lib.getExe pkgs.git} stash";
      gsp = "${lib.getExe pkgs.git} stash pop";
      gckb = "${lib.getExe pkgs.git} checkout -b";
      gck = "${lib.getExe pkgs.git} checkout";
      gdf = "${lib.getExe pkgs.git} diff";
      gb = "${lib.getExe pkgs.git} branches";
      gbd = "${lib.getExe pkgs.git} branch -D";
      gprc = "${lib.getExe pkgs.gh} pr create";
      sync-upstream = "${lib.getExe pkgs.git} fetch upstream main && ${lib.getExe pkgs.git} rebase FETCH_HEAD --autosquash --ff && ${lib.getExe pkgs.git} push";
      merge-upstream = "${lib.getExe pkgs.git} fetch upstream main && ${lib.getExe pkgs.git} merge FETCH_HEAD --ff && ${lib.getExe pkgs.git} push";

      # editor
      v = lib.getExe config.programs.neovim.finalPackage;
      vi = lib.getExe pkgs.vim;
      f = ''${lib.getExe pkgs.fd} --type f --hidden --exclude .git | ${lib.getExe pkgs.fzf} --preview "_fzf_complete_realpath {}" | xargs ${lib.getExe pkgs.neovim}'';

      # general
      cx = "chmod +x";
      cdx = "chmod -x";
      copy = lib.getExe pkgs.unicopy;

      # aliases
      pip = ''${lib.getExe pkgs.uv} pip'';
      b = ''bentoml'';
      k = lib.getExe pkgs.kubectl;
      cat = lib.getExe pkgs.bat;
      hf = ''${lib.getExe' pkgs.uv "uvx"} --from 'huggingface-hub[cli]' --quiet huggingface-cli'';
      jupytertext = ''${lib.getExe' pkgs.uv "uvx"} jupytertext'';
      ipynb = ''${lib.getExe' pkgs.uv "uvx"} --from 'jupyter_core' jupyter notebook --autoreload --debug'';
      ipy = "ipython --autoindent";
      pinentry = lib.getExe (
        if pkgs.stdenv.isDarwin
        then pkgs.pinentry_mac
        else pkgs.pinentry-all
      );
      ghostty =
        if pkgs.stdenv.isDarwin
        then ''$GHOSTTY_BIN_DIR/ghostty''
        else lib.getExe pkgs.ghostty;

      # useful
      bwpass = ''[[ -f ${config.home.homeDirectory}/bw.master ]] && cat ${config.home.homeDirectory}/bw.master | sed -n 1p | ${lib.getExe pkgs.unicopy}'';
      unlock-vault = ''bw unlock --check &>/dev/null || export BW_SESSION=''${BW_SESSION:-"$(bw unlock --passwordenv BW_MASTER --raw)"}'';
      generate-password = "bw generate --special --uppercase --minSpecial 12 --length 80 | ${lib.getExe pkgs.unicopy}";
      lock-workflow = ''${lib.getExe pkgs.fd} -Hg "*.y[a]ml" .github --exec-batch docker run --rm -v "''${PWD}":"''${PWD}" -w "''${PWD}" -e RATCHET_EXP_KEEP_NEWLINES=true ghcr.io/sethvargo/ratchet:0.9.2 update'';
      get-redirect = ''${lib.getExe pkgs.curl} -Ls -o /dev/null -w %{url_effective} $@'';
      gpgpass = ''bw get notes gpg-personal-keys | ${lib.getExe pkgs.unicopy}'';
      sshpass = ''bw get notes gpg-age-ssh-key | ${lib.getExe pkgs.unicopy}'';

      # nix-commands
      ncg = "nix-collect-garbage -d";
      nsp = "nix-shell --pure";
      nstr = "nix-store --gc --print-roots";

      python-format = ''ruff format --config "indent-width=2" --config "line-length=119" --config "preview=true"'';
    };
  };
}
