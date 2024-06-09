{ config, pkgs, lib, user, ... }:
let
  env = import ../dix { inherit pkgs lib; };

  fzfConfig = pkgs.writeText "fzfrc" ''
    --cycle --bind 'tab:toggle-up,btab:toggle-down' --prompt='» ' --marker='»' --pointer='◆' --info=right --layout='reverse' --border='sharp' --preview-window='border-sharp' --height='80%'
  '';

  gpgTuiConfig = pkgs.writeText "gpg-tui.toml" ''
    [general]
      detail_level = "full"
    [gpg]
      armor = true
  '';
  gpgTuiConfigFile = "${if pkgs.stdenv.isDarwin then "/Library/Application Support" else ".config"}/gpg-tui/gpg-tui.toml";
in
(if pkgs.stdenv.isLinux then {
  home.packages = env.packages;
  home.sessionVariables = env.variables;
} else { }) //
{
  imports = [ ./modules ];

  programs.home-manager.enable = true;

  zsh.enable = true;
  git.enable = true;
  bat.enable = true;
  alacritty.enable = true;
  btop.enable = true;
  system.enable = true;
  ssh.enable = true;
  gpg.enable = true;

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
      ".." = "__zoxide_z ..";
      "..." = "__zoxide_z ../..";
      "...." = "__zoxide_z ../../..";
      "....." = "__zoxide_z ../../../..";

      # ls-replacement
      ls = "${pkgs.eza}/bin/eza";
      ll = "${pkgs.eza}/bin/eza -la --group-directories-first -snew --icons always";
      sudo = "nocorrect sudo";

      # safe rm
      rm = "${pkgs.rm-improved}/bin/rip --graveyard ${config.home.homeDirectory}/.local/share/Trash";

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
      bwpass = "[[ -f ${config.home.homeDirectory}/bw.master ]] && cat ${config.home.homeDirectory}/bw.master | sed -n 1p | pbcopy";
      bwunlock = ''${pkgs.dix.bitwarden-cli}/bin/bw unlock --check &>/dev/null || export BW_SESSION=''${BW_SESSION:-"$(bw unlock --passwordenv BW_MASTER --raw)"}'';

      # useful
      generate-password = "${pkgs.dix.bitwarden-cli}/bin/bw generate --special --uppercase --minSpecial 12 --length 80 | pbcopy";
      lock-workflow = ''${pkgs.fd}/bin/fd -Hg "*.yml" .github --exec-batch docker run --rm -v "''${PWD}":"''${PWD}" -w "''${PWD}" -e RATCHET_EXP_KEEP_NEWLINES=true ghcr.io/sethvargo/ratchet:0.9.2 update'';
      get-redirect = ''${pkgs.curl}/bin/curl -Ls -o /dev/null -w %{url_effective} $@'';

      # nix-commands
      nrb = ''pushd $WORKSPACE/dix &>/dev/null && darwin-rebuild switch --flake ".#appl-mbp16" --verbose && popd &>/dev/null'';
      ned = "$EDITOR $WORKSPACE/dix/darwin/appl-mbp16.nix";
      nflp = "nix-env -qaP | grep $1";
      ncg = "nix-collect-garbage -d";
      nsp = "nix-shell --pure";
      nstr = "nix-store --gc --print-roots";

      # program opts
      cat = "${pkgs.bat}/bin/bat";
      # python
      pip = "uv pip";
      python3 = ''$(${pkgs.pyenv}/bin/pyenv root)/shims/python'';
      python-install = ''CPPFLAGS="-I${pkgs.zlib.outPath}/include -I${pkgs.xz.dev.outPath}/include" LDFLAGS="-L${pkgs.zlib.outPath}/lib -L${pkgs.xz.dev.outPath}/lib" pyenv install "$@"'';
      ipynb = "jupyter notebook --autoreload --debug";
      ipy = "ipython";
      k = "${pkgs.kubectl}/bin/kubectl";
    } // (if pkgs.stdenv.isDarwin then {
      pinentry = ''${pkgs.pinentry_mac}/bin/pinentry-mac'';
    } else {
      pinentry = ''${pkgs.pinentry-all}/bin/pinentry'';
    });
  };

  home.file = {
    ".fzfrc".source = fzfConfig;
    "${gpgTuiConfigFile}".source = gpgTuiConfig;
  };
}
