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
  zshOptions = pkgs.lib.readFile ./options.zsh;
  zshFunctions = pkgs.lib.readFile ./functions.zsh;
  zshCompletions = pkgs.lib.readFile ./completions.zsh;
in
{
  # Users
  users.users.${vars.user} = {
    home = "/Users/${vars.user}";
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
    hostName = "apple-mbp16";
  };

  # System preferences
  system = {
    activationScripts.postActivation.text = ''sudo chsh -s ${pkgs.zsh}/bin/zsh'';
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
    };
    gc = {
      automatic = true;
      interval.Day = 7; #Hours, minutes
      options = "--delete-older-than 7d";
    };
  };

  environment = {
    darwinConfig = "${vars.wsDir}/dix";

    # shells related
    shells = with pkgs; [ zsh ];
    variables = lib.mkMerge [
      xdg
      bentoml
      {
        # language
        GOPATH = "${pkgs.go.out}";
        # set nix-index to $HOME/.cache
        NIX_INDEX_DATABASE = "${vars.cacheDir}/nix-index/";
        # editors
        EDITOR = "${vars.editor}";
        VISUAL = "${vars.editor}";
        WORKSPACE = "${vars.wsDir}";
        SHELL = "${pkgs.zsh}/bin/zsh";
        # misc
        SQLITE_PATH = ''${pkgs.sqlite.out}/lib/libsqlite3.dylib'';
        PAPERSPACE_INSTALL = "${vars.homeDir}/.paperspace";
        PATH = "${pkgs.protobuf.out}/bin:$PAPERSPACE_INSTALL/bin:$PATH";
        # fzf
        FZF_DEFAULT_OPTS = ''--no-mouse --bind "?:toggle-preview,ctrl-a:select-all,ctrl-d:preview-page-down,ctrl-u:preview-page-up"'';
        FZF_CTRL_T_COMMAND = ''${pkgs.fd.out}/bin/fd --hidden --follow --exclude .git'';
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
      nrb = "darwin-rebuild switch -I $WORKSPACE/dix --flake \".#appl-mbp16\"";
      ned = "$EDITOR ${vars.wsDir}/dix/darwin/appl-mbp16.nix";
      nflp = "nix-env -qaP | grep $1";
      ncg = "nix-collect-garbage -d";
      nsp = "nix-shell --pure";

      # program opts
      cat = "${pkgs.bat.out}/bin/bat";
      ipynb = "jupyter notebook --autoreload --debug";
      pip = "uv pip";
    };

    systemPackages = with pkgs; [
      # nix
      niv
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

      # languages
      # TODO: setup python, pyenv, openjdk, rust, nvm
      go
      sass
      protobuf
      # tools for language, lsp, linter, etc.
      tree-sitter
      eclint
      nixfmt-rfc-style
      grpcurl
      taplo
      stylua
      selene
      buf
      protolint
      sqlite
      postgresql_14
      llvm_17

      # terminal
      # TODO: GPG
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
      any-nix-shell
      ffmpeg
      cmake
      dtach
      enchant
      zstd
      gnused
      gnupg
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
      enableFzfCompletion = true;
      enableFzfHistory = true; # ctrl-r
      enableSyntaxHighlighting = true;
      interactiveShellInit = ''

        # shell configuration
        unsetopt EXTENDED_GLOB # no expanding glob

        eval "$(${pkgs.direnv.out}/bin/direnv hook zsh)"
        eval "$(${pkgs.zoxide.out}/bin/zoxide init --cmd j zsh)"
        ${pkgs.any-nix-shell.out}/bin/any-nix-shell zsh --info-right | source /dev/stdin
      '';
    };
  };
}
