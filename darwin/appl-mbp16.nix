{ inputs, lib, pkgs, vars, ... }:
let
  xdg = {
    XDG_CONFIG_HOME = "${vars.configDir}";
    XDG_DATA_HOME = "${vars.localDir}/share";
    XDG_BIN_HOME = "${vars.localDir}/bin";
    XDG_CACHE_HOME = "${vars.cacheDir}";
  };
  # work
  bentoml = {
    BENTOML_HOME = "$XDG_DATA_HOME/bentoml";
    BENTOML_DO_NOT_TRACK = "True";
    BENTOML_BUNDLE_LOCAL_BUILD = "True";
    OPENLLM_DEV_BUILD = "True";
    OPENLLM_DISABLE_WARNING = "False";
  };
  pyenv_root = ''${vars.homeDir}/.pyenv'';
  userDir = ''/Users/${vars.user}'';
in
{
  # Users
  users.users.${vars.user} = {
    home = userDir;
    shell = pkgs.zsh;
  };

  # add PAM
  security.pam.enableSudoTouchIdAuth = true;

  # Auto upgrade nix package and the daemon service.
  services = {
    nix-daemon.enable = true;
  };

  # Networking
  networking = {
    knownNetworkServices = [ "Wi-Fi" ];
    dns = [ "1.1.1.1" "8.8.8.8" ];
    computerName = "appl-mbp16";
    hostName = "appl-mbp16";
  };

  # System preferences
  system = {
    activationScripts.postActivation.text = ''
      ln -sf /etc/nvim ${userDir}/.config/nvim
    '';
    # Set Git commit hash for darwin-version.
    configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 4;
    # default settings within System Preferences
    defaults = {
      NSGlobalDomain = {
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };
      dock = {
        autohide = false;
        largesize = 36;
        tilesize = 24;
        magnification = true;
        mineffect = "genie";
        orientation = "bottom";
        showhidden = false;
        show-recents = false;
      };
      finder = {
        AppleShowAllFiles = true;
        QuitMenuItem = false;
      };
      trackpad = {
        Clicking = true;
        TrackpadRightClick = true;
      };
    };
  };

  nix = {
    package = pkgs.nix;
    settings = {
      experimental-features = "nix-command flakes";
      trusted-users = [ "root" "${vars.user}" ];
      trusted-substituters = [ "https://nix-community.cachix.org" ];
      trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
    };
    gc = {
      automatic = true;
      interval.Day = 7; #Hours, minutes
      options = "--delete-older-than 7d";
    };
  };

  environment = {
    darwinConfig = "${vars.wsDir}/dix";
    etc = {
      "nvim" = {
        source = "${pkgs.aarnphm-editor}/nvim";
      };
    };
    # shells related
    shells = with pkgs; [ zsh ];
    variables = lib.mkMerge [
      xdg
      bentoml
      {
        # fzf
        FZF_DEFAULT_OPTS = ''--no-mouse --bind "?:toggle-preview,ctrl-a:select-all,ctrl-d:preview-page-down,ctrl-u:preview-page-up"'';
        FZF_CTRL_T_COMMAND = ''${pkgs.fd.out}/bin/fd --hidden --follow --exclude .git'';
        # language
        GOPATH = "${pkgs.go.out}";
        PYENV_ROOT = "${pyenv_root}";
        UV_PYTHON = ''${pyenv_root}/shims/python'';
        PYTHON3_HOST_PROG = ''${pyenv_root}/shims/python'';
        # set nix-index to $HOME/.cache
        NIX_INDEX_DATABASE = "${vars.cacheDir}/nix-index/";
        # editors
        EDITOR = "${pkgs.neovim-developer}/bin/nvim";
        VISUAL = "${pkgs.neovim-developer}/bin/nvim";
        WORKSPACE = "${vars.wsDir}";
        SHELL = "${pkgs.zsh}/bin/zsh";
        # misc
        PYENCHANT_LIBRARY_PATH = ''${pkgs.enchant}/lib/libenchant-2.2.dylib'';
        OPENBLAS = ''${pkgs.openblas}/lib/libopenblas.dylib'';
        SQLITE_PATH = ''${pkgs.sqlite}/lib/libsqlite3.dylib'';
        PAPERSPACE_INSTALL = "$HOME/.paperspace";
        PATH = lib.concatStringsSep ":" [ ''${pyenv_root}/shims'' "${lib.makeBinPath [ "$HOME/.cargo" pkgs.protobuf "$PAPERSPACE_INSTALL" "$HOME/.orbstack" ]}" "$PATH" ];
        LD_LIBRARY_PATH = ''${lib.makeLibraryPath [ pkgs.openssl.dev pkgs.zlib.dev pkgs.xz.dev pkgs.stdenv.cc.cc.lib pkgs.readline.dev pkgs.protobuf pkgs.cairo ]}'';
      }
    ];
    shellAliases = {
      reload = "exec -l $SHELL";
      afk = "pmset displaysleepnow";

      # ls-replacement
      ls = "${pkgs.eza.out}/bin/eza";
      ll = "${pkgs.eza.out}/bin/eza -la --group-directories-first -snew --icons";

      # safe rm
      rm = "${pkgs.rm-improved.out}/bin/rip --graveyard ${vars.localDir}/share/Trash";

      # git
      g = "${pkgs.git.out}/bin/git";
      ga = "${pkgs.git.out}/bin/git add";
      gaa = "${pkgs.git.out}/bin/git add .";
      gsw = "${pkgs.git.out}/bin/git switch";
      gcm = "${pkgs.git.out}/bin/git commit -S --signoff -sv";
      gcmm = "${pkgs.git.out}/bin/git commit -S --signoff -svm";
      gcma = "${pkgs.git.out}/bin/git commit -S --signoff -sv --amend";
      gcman = "${pkgs.git.out}/bin/git commit -S --signoff -sv --amend --no-edit";
      grpo = "${pkgs.git.out}/bin/git remote prune origin";
      grst = "${pkgs.git.out}/bin/git restore";
      grsts = "${pkgs.git.out}/bin/git restore --staged";
      gst = "${pkgs.git.out}/bin/git status";
      gsi = "${pkgs.git.out}/bin/git status --ignored";
      gsm = "${pkgs.git.out}/bin/git status -sb";
      gfom = "${pkgs.git.out}/bin/git fetch origin main";
      grfh = "${pkgs.git.out}/bin/git rebase -i FETCH_HEAD";
      grb = "${pkgs.git.out}/bin/git rebase -i -S --signoff";
      gra = "${pkgs.git.out}/bin/git rebase --abort";
      grc = "${pkgs.git.out}/bin/git rebase --continue";
      gri = "${pkgs.git.out}/bin/git rebase -i";
      gcp = "${pkgs.git.out}/bin/git cherry-pick --gpg-sign --signoff";
      gcpa = "${pkgs.git.out}/bin/git cherry-pick --abort";
      gcpc = "${pkgs.git.out}/bin/git cherry-pick --continue";
      gp = "${pkgs.git.out}/bin/git pull";
      gpu = "${pkgs.git.out}/bin/git push";
      gpuf = "${pkgs.git.out}/bin/git push --force-with-lease";
      gs = "${pkgs.git.out}/bin/git stash";
      gsp = "${pkgs.git.out}/bin/git stash pop";
      gckb = "${pkgs.git.out}/bin/git checkout -b";
      gck = "${pkgs.git.out}/bin/git checkout";
      gdf = "${pkgs.git.out}/bin/git diff";
      gprc = "${pkgs.gh.out}/bin/gh pr create";

      # editor
      v = "${pkgs.neovim-developer.out}/bin/nvim";
      vi = "${pkgs.vim.out}/bin/vim";

      # general
      cx = "chmod +x";
      freeport = "sudo fuser -k $@";
      copy = "pbcopy";
      bwpass = "[[ -f $HOME/bw.pass ]] && cat $HOME/bw.pass | sed -n 1p | pbcopy";

      # nix-commands
      nrb = "pushd ${vars.wsDir}/dix &>/dev/null && darwin-rebuild switch --flake \".#appl-mbp16\" && popd &>/dev/null";
      ned = "$EDITOR ${vars.wsDir}/dix/darwin/appl-mbp16.nix";
      nflp = "nix-env -qaP | grep $1";
      ncg = "nix-collect-garbage -d";
      nsp = "nix-shell --pure";

      # program opts
      cat = "${pkgs.bat.out}/bin/bat";
      # python
      pip = "uv pip";
      python3 = ''${pyenv_root}/shims/python'';
      python-install = ''CPPFLAGS="-I${pkgs.zlib.outPath}/include -I${pkgs.xz.dev.outPath}/include" LDFLAGS="-L${pkgs.zlib.outPath}/lib -L${pkgs.xz.dev.outPath}/lib" pyenv install "$@"'';
      ipynb = "jupyter notebook --autoreload --debug";
    };

    systemPackages = with pkgs; [
      # nix
      cachix

      # editor
      vim
      neovim-developer
      alacritty
      aarnphm-editor

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
      # TODO: setup openjdk
      go
      sass
      protobuf
      nodejs_20
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
      zsh-powerlevel10k
      zsh-completions
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
    ];
  };


  programs = {
    nix-index = { enable = true; };
    gnupg = {
      agent.enable = true;
      agent.enableSSHSupport = true;
    };
    zsh = {
      enable = true;
      enableFzfHistory = true; # ctrl-r
      enableSyntaxHighlighting = true;
      promptInit = "source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      shellInit = ''
        [[ -d ${vars.homeDir}/.cargo/env ]] && . "${vars.homeDir}/.cargo/env"
      '';
      loginShellInit = ''
        source $HOME/.orbstack/shell/init.zsh 2>/dev/null || :

        fpath+=(${pkgs.zsh-completions}/share/zsh/site-functions)
      '';
      interactiveShellInit = ''
        eval "$(${pkgs.direnv.out}/bin/direnv hook zsh)"
        eval "$(${pkgs.zoxide.out}/bin/zoxide init --cmd j zsh)"
        eval "$(${pkgs.pyenv.out}/bin/pyenv init -)"
        ${pkgs.any-nix-shell.out}/bin/any-nix-shell zsh --info-right | source /dev/stdin

        source ${./completions.zsh}
        source ${./functions.zsh}
        source ${./options.zsh}
        source ${./p10k.zsh}
      '';
    };
  };
}





