{ config, pkgs, user, ... }:
{
  imports = [ ./modules ];

  programs.home-manager.enable = true;

  zsh.enable = true;
  git.enable = true;
  bat.enable = true;
  alacritty.enable = true;

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
      ".." = "${pkgs.eza}/bin/eza ..";
      "..." = "${pkgs.eza}/bin/eza ../..";
      "...." = "${pkgs.eza}/bin/eza ../../..";
      "....." = "${pkgs.eza}/bin/eza ../../../..";

      # ls-replacement
      ls = "${pkgs.eza}/bin/eza";
      ll = "${pkgs.eza}/bin/eza -la --group-directories-first -snew --icons always";
      sudo = "nocorrect sudo";

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
  home.file.".config/zed/keymap.json".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/zed/keymap.json";
  home.file.".config/zed/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/zed/settings.json";
}


