{ pkgs, user, inputs, ... }: {
  imports = [ ./modules ../modules ];

  home-manager.users.${user} = {
    home.stateVersion = "24.11";
  };

  # Users
  users.users.${user} = {
    shell = pkgs.zsh;
    home = "/Users/${user}";
    createHome = true;
  };

  skhd.enable = true;
  yabai.enable = false;
  sketchybar.enable = false;
  zsh.enable = true;

  # shells related
  environment.shellAliases = {
    reload = "exec -l $SHELL";
    afk = "pmset displaysleepnow";
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    "....." = "cd ../../../..";

    # ls-replacement
    ls = "${pkgs.eza}/bin/eza";
    ll = "${pkgs.eza}/bin/eza -la --group-directories-first -snew --icons always";

    # safe rm
    rm = "${pkgs.rm-improved}/bin/rip --graveyard $HOME/.local/share/Trash";

    # git
    g = "${pkgs.git}/bin/git";
    ga = "${pkgs.git}/bin/git add";
    gaa = "${pkgs.git}/bin/git add .";
    gsw = "${pkgs.git}/bin/git switch";
    gcm = "${pkgs.git}/bin/git commit -S --signoff -sv";
    gcmm = "${pkgs.git}/bin/git commit -S --signoff -svm";
    gcma = "${pkgs.git}/bin/git commit -S --signoff -sv --amend";
    gcman = "${pkgs.git}/bin/git commit -S --signoff -sv --amend --no-edit";
    grpo = "${pkgs.git}/bin/git remote prune origin";
    grst = "${pkgs.git}/bin/git restore";
    grsts = "${pkgs.git}/bin/git restore --staged";
    gst = "${pkgs.git}/bin/git status";
    gsi = "${pkgs.git}/bin/git status --ignored";
    gsm = "${pkgs.git}/bin/git status -sb";
    gfom = "${pkgs.git}/bin/git fetch origin main";
    grfh = "${pkgs.git}/bin/git rebase -i FETCH_HEAD";
    grb = "${pkgs.git}/bin/git rebase -i -S --signoff";
    gra = "${pkgs.git}/bin/git rebase --abort";
    grc = "${pkgs.git}/bin/git rebase --continue";
    gri = "${pkgs.git}/bin/git rebase -i";
    gcp = "${pkgs.git}/bin/git cherry-pick --gpg-sign --signoff";
    gcpa = "${pkgs.git}/bin/git cherry-pick --abort";
    gcpc = "${pkgs.git}/bin/git cherry-pick --continue";
    gp = "${pkgs.git}/bin/git pull";
    gpu = "${pkgs.git}/bin/git push";
    gpuf = "${pkgs.git}/bin/git push --force-with-lease";
    gs = "${pkgs.git}/bin/git stash";
    gsp = "${pkgs.git}/bin/git stash pop";
    gckb = "${pkgs.git}/bin/git checkout -b";
    gck = "${pkgs.git}/bin/git checkout";
    gdf = "${pkgs.git}/bin/git diff";
    gb = "${pkgs.git}/bin/git branches";
    gprc = "${pkgs.gh}/bin/gh pr create";

    # editor
    v = "${pkgs.neovim-developer}/bin/nvim";
    vi = "${pkgs.vim}/bin/vim";

    # general
    cx = "chmod +x";
    freeport = "sudo fuser -k $@";
    copy = "pbcopy";
    bwpass = "[[ -f $HOME/bw.pass ]] && cat $HOME/bw.pass | sed -n 1p | pbcopy";

    # nix-commands
    nrb = ''pushd $WORKSPACE/dix &>/dev/null && darwin-rebuild switch --flake ".#appl-mbp16" --verbose && popd &>/dev/null'';
    ned = "$EDITOR $WORKSPACE/dix/darwin/appl-mbp16.nix";
    nflp = "nix-env -qaP | grep $1";
    ncg = "nix-collect-garbage -d";
    nsp = "nix-shell --pure";

    # program opts
    cat = "${pkgs.bat}/bin/bat";
    # python
    pip = "uv pip";
    python3 = ''$(${pkgs.pyenv}/bin/pyenv root)/shims/python'';
    python-install = ''CPPFLAGS="-I${pkgs.zlib.outPath}/include -I${pkgs.xz.dev.outPath}/include" LDFLAGS="-L${pkgs.zlib.outPath}/lib -L${pkgs.xz.dev.outPath}/lib" pyenv install "$@"'';
    ipynb = "jupyter notebook --autoreload --debug";
    ipy = "ipython";
  };

  services.nix-daemon.enable = true;
  # Set Git commit hash for darwin-version.
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      sketchybar-app-font
      (nerdfonts.override {
        fonts = [
          "FiraCode"
        ];
      })
    ];
  };

  # Networking
  networking = {
    knownNetworkServices = [ "Wi-Fi" ];
    dns = [ "1.1.1.1" "8.8.8.8" ];
    computerName = "appl-mbp16";
    hostName = "appl-mbp16";
  };

  # add PAM
  security.pam.enableSudoTouchIdAuth = true;

  # System preferences
  system = {
    activationScripts.extraUserActivation.text = ''sudo chsh -s ${pkgs.zsh}/bin/zsh'';
    # default settings within System Preferences
    defaults = {
      NSGlobalDomain = {
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
      };
      dock = {
        autohide = true;
        largesize = 48;
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


  programs.nix-index.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };
}
