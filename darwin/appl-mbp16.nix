{ pkgs, lib, user, ... }: {
  imports = [ ../modules ./modules ];

  home-manager.users.${user} = {
    home.stateVersion = "24.11";
  };

  # Users
  users.users.${user} = {
    shell = pkgs.zsh;
    home = "/Users/${user}";
    createHome = true;
  };

  # add PAM
  security.pam.enableSudoTouchIdAuth = true;

  skhd.enable = true;
  yabai.enable = true;
  sketchybar.enable = true;

  environment = {
    # shells related
    shellAliases = {
      reload = "exec -l $SHELL";
      afk = "pmset displaysleepnow";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";

      # ls-replacement
      ls = "${pkgs.eza.out}/bin/eza";
      ll = "${pkgs.eza.out}/bin/eza -la --group-directories-first -snew --icons";

      # safe rm
      rm = "${pkgs.rm-improved.out}/bin/rip --graveyard $HOME/.local/share/Trash";

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
      gb = "${pkgs.git.out}/bin/git branches";
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
      nrb = ''pushd $WORKSPACE/dix &>/dev/null && darwin-rebuild switch --flake ".#appl-mbp16" --verbose && popd &>/dev/null'';
      ned = "$EDITOR $WORKSPACE/dix/darwin/appl-mbp16.nix";
      nflp = "nix-env -qaP | grep $1";
      ncg = "nix-collect-garbage -d";
      nsp = "nix-shell --pure";

      # program opts
      cat = "${pkgs.bat.out}/bin/bat";
      # python
      pip = "uv pip";
      python3 = ''$(${pkgs.pyenv} root)/shims/python'';
      python-install = ''CPPFLAGS="-I${pkgs.zlib.outPath}/include -I${pkgs.xz.dev.outPath}/include" LDFLAGS="-L${pkgs.zlib.outPath}/lib -L${pkgs.xz.dev.outPath}/lib" pyenv install "$@"'';
      ipynb = "python -m jupyter notebook --autoreload --debug";
    };

    systemPackages = with pkgs; [
      # nix
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
      zsh-f-sy-h
      zsh-history-substring-search

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
    zsh = {
      enable = true;
      enableFzfHistory = true; # ctrl-r
      promptInit = "source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      shellInit = ''
        [[ -d $HOME/.cargo ]] && . "$HOME/.cargo/env"
      '';
      loginShellInit = ''
        eval "$(${pkgs.pyenv}/bin/pyenv init -)"
        source $HOME/.orbstack/shell/init.zsh 2>/dev/null || :

        fpath+=(
          ${pkgs.zsh-completions}/share/zsh/site-functions
        )
      '';
      interactiveShellInit = ''
        source ${pkgs.zsh-dix}/share/zsh/dix.plugin.zsh
        source ${pkgs.zsh-f-sy-h}/share/zsh/site-functions/F-Sy-H.plugin.zsh
        source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
      '';
    };
  };

  environment.etc."zshrc.local".text = ''
    eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
    eval "$(${pkgs.zoxide}/bin/zoxide init --cmd j zsh)"
    ${pkgs.any-nix-shell}/bin/any-nix-shell zsh --info-right | source /dev/stdin
  '';
}
