{ config, pkgs, user, ... }:
{
  imports = [ ./modules ];
  programs.home-manager.enable = true;

  zsh.enable = true;
  git.enable = true;

  home.username = user;

  home.homeDirectory = pkgs.lib.mkForce (
    if pkgs.stdenv.isLinux
    then "/home/${user}"
    else "/Users/${user}"
  );

  home = {
    stateVersion = "24.11";

    # shells related
    shellAliases = {
      reload = "exec -l $SHELL";
      afk = "pmset displaysleepnow";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";

      # ls-replacement
      ls = "${pkgs.eza}/bin/eza";
      ll = "${pkgs.eza}/bin/eza -la --group-directories-first -snew --icons always";
      sudo = "nocorrect sudo";

      # safe rm
      rm = "${pkgs.rm-improved}/bin/rip --graveyard $HOME/.local/share/Trash";

      # git
      g = "${pkgs.gitFull}/bin/git";
      ga = "${pkgs.gitFull}/bin/git add";
      gaa = "${pkgs.gitFull}/bin/git add .";
      gsw = "${pkgs.gitFull}/bin/git switch";
      gcm = "${pkgs.gitFull}/bin/git commit -S --signoff -sv";
      gcmm = "${pkgs.gitFull}/bin/git commit -S --signoff -svm";
      gcma = "${pkgs.gitFull}/bin/git commit -S --signoff -sv --amend";
      gcman = "${pkgs.gitFull}/bin/git commit -S --signoff -sv --amend --no-edit";
      grpo = "${pkgs.gitFull}/bin/git remote prune origin";
      grst = "${pkgs.gitFull}/bin/git restore";
      grsts = "${pkgs.gitFull}/bin/git restore --staged";
      gst = "${pkgs.gitFull}/bin/git status";
      gsi = "${pkgs.gitFull}/bin/git status --ignored";
      gsm = "${pkgs.gitFull}/bin/git status -sb";
      gfom = "${pkgs.gitFull}/bin/git fetch origin main";
      grfh = "${pkgs.gitFull}/bin/git rebase -i FETCH_HEAD";
      grb = "${pkgs.gitFull}/bin/git rebase -i -S --signoff";
      gra = "${pkgs.gitFull}/bin/git rebase --abort";
      grc = "${pkgs.gitFull}/bin/git rebase --continue";
      gri = "${pkgs.gitFull}/bin/git rebase -i";
      gcp = "${pkgs.gitFull}/bin/git cherry-pick --gpg-sign --signoff";
      gcpa = "${pkgs.gitFull}/bin/git cherry-pick --abort";
      gcpc = "${pkgs.gitFull}/bin/git cherry-pick --continue";
      gp = "${pkgs.gitFull}/bin/git pull";
      gpu = "${pkgs.gitFull}/bin/git push";
      gpuf = "${pkgs.gitFull}/bin/git push --force-with-lease";
      gs = "${pkgs.gitFull}/bin/git stash";
      gsp = "${pkgs.gitFull}/bin/git stash pop";
      gckb = "${pkgs.gitFull}/bin/git checkout -b";
      gck = "${pkgs.gitFull}/bin/git checkout";
      gdf = "${pkgs.gitFull}/bin/git diff";
      gb = "${pkgs.gitFull}/bin/git branches";
      gprc = "${pkgs.gh}/bin/gh pr create";

      # editor
      v = "${pkgs.neovim-developer}/bin/nvim";
      vi = "${pkgs.vim}/bin/vim";

      # general
      cx = "chmod +x";
      freeport = "sudo fuser -k $@";
      copy = "pbcopy";
      bwpass = "[[ -f $HOME/bw.master ]] && cat $HOME/bw.master | sed -n 1p | pbcopy";
      password = "${pkgs.bitwarden-cli}/bin/bw generate --special --uppercase --minSpecial 12 --length 80 | pbcopy";

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
      k = "${pkgs.kubectl}/bin/kubectl";
    };
  };

  home.file.".config/nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "${pkgs.vimPlugins.vim-nix}";
    recursive = true;
  };
  home.file.".fzfrc".text = ''
    --prompt='» ' --marker='»' --pointer='◆' --info=right --layout='reverse' --border='sharp' --preview-window='border-sharp' --height='80%'
  '';
  home.file.".config/alacritty" = {
    source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/alacritty";
    recursive = true;
  };
  home.file.".config/wezterm" = {
    source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/wezterm";
    recursive = true;
  };
  home.file.".config/kitty" = {
    source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/kitty";
    recursive = true;
  };
  home.file.".config/zed/keymap.json".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/zed/keymap.json";
  home.file.".config/zed/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/zed/settings.json";
}


