{
  config,
  inputs,
  pkgs,
  lib,
  user,
  ...
}: let
  tomlFormat = pkgs.formats.toml {};

  fzfConfig = pkgs.writeText "fzfrc" ''
    --color=fg:#797593,bg:#faf4ed,hl:#d7827e
    --color=fg+:#575279,bg+:#f2e9e1,hl+:#d7827e
    --color=border:#dfdad9,header:#286983,gutter:#faf4ed
    --color=spinner:#ea9d34,info:#56949f,separator:#dfdad9
    --color=pointer:#907aa9,marker:#b4637a,prompt:#797593
    --bind='ctrl-/:toggle-preview'
    --bind='ctrl-u:preview-page-up'
    --bind='ctrl-d:preview-page-down'
    --preview-window 'right:40%:wrap'
    --cycle --bind 'tab:toggle-up,btab:toggle-down' --prompt='» ' --marker='»' --pointer='◆' --info=right --layout='reverse' --border='sharp' --preview-window='border-sharp' --height='80%'
  '';

  gpgTuiConfig = {
    general = {detail_level = "full";};
    gpg = {armor = true;};
  };

  gpgTuiConfigFile = "${
    if pkgs.stdenv.isDarwin
    then "/Library/Application Support"
    else ".config"
  }/gpg-tui/gpg-tui.toml";
in {
  imports = [./modules];

  programs.home-manager.enable = true;
  programs.nix-index.enable = true;
  programs.dircolors = {
    enable = true;
    enableZshIntegration = true;
  };

  zsh.enable = true;
  zoxide.enable = true;
  git.enable = true;
  bat.enable = true;
  alacritty.enable = true;
  btop.enable = true;
  system.enable = true;
  ssh.enable = true;
  direnv.enable = true;
  gpg.enable = true;
  awscli.enable = true;

  # MacOS specifics
  zed.enable = true;
  karabiner.enable = true;

  home.username = user;

  home.homeDirectory = pkgs.lib.mkForce (
    if pkgs.stdenv.isLinux
    then "/home/${user}"
    else "/Users/${user}"
  );

  home.stateVersion = "24.11";
  home.file = {
    ".fzfrc".source = fzfConfig;
    "${gpgTuiConfigFile}".source = tomlFormat.generate "gpg-tui-config" gpgTuiConfig;
  };

  home = {
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
      gprc = "${lib.getExe pkgs.gh} pr create";

      # editor
      v = "${lib.getExe pkgs.neovim}";
      vi = "${lib.getExe pkgs.vim}";
      f = ''${lib.getExe pkgs.fd} --type f --hidden --exclude .git | ${lib.getExe pkgs.fzf} --preview "_fzf_complete_realpath {}" | xargs ${lib.getExe pkgs.neovim}'';

      # general
      cx = "chmod +x";
      freeport = "sudo fuser -k $@";
      copy = lib.getExe pkgs.dix.unicopy;

      # useful
      bwpass = "[[ -f ${config.home.homeDirectory}/bw.master ]] && cat ${config.home.homeDirectory}/bw.master | sed -n 1p | ${lib.getExe pkgs.dix.unicopy}";
      unlock-vault = ''${lib.getExe pkgs.dix.bitwarden-cli} unlock --check &>/dev/null || export BW_SESSION=''${BW_SESSION:-"$(${lib.getExe pkgs.dix.bitwarden-cli} unlock --passwordenv BW_MASTER --raw)"}'';
      generate-password = "${lib.getExe pkgs.dix.bitwarden-cli} generate --special --uppercase --minSpecial 12 --length 80 | ${lib.getExe pkgs.dix.unicopy}";
      lock-workflow = ''${lib.getExe pkgs.fd} -Hg "*.yml" .github --exec-batch ${
          if pkgs.stdenv.isDarwin
          then "${pkgs.dix.OrbStack}/bin/docker"
          else "docker"
        } run --rm -v "''${PWD}":"''${PWD}" -w "''${PWD}" -e RATCHET_EXP_KEEP_NEWLINES=true ghcr.io/sethvargo/ratchet:0.9.2 update'';
      get-redirect = ''${lib.getExe pkgs.curl} -Ls -o /dev/null -w %{url_effective} $@'';
      get-gpg-password = ''${lib.getExe pkgs.dix.bitwarden-cli} get notes gpg-github-keys | ${lib.getExe pkgs.dix.unicopy}'';

      # nix-commands
      nrbd = ''darwin-rebuild switch --flake "$WORKSPACE/dix#appl-mbp16" -vvv --show-trace'';
      nrbl = ''home-manager switch --flake "$WORKSPACE/dix#paperspace" --show-trace'';
      ned = "${lib.getExe pkgs.neovim} $WORKSPACE/dix/flake.nix";
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
      k =
        if pkgs.stdenv.isDarwin
        then "${pkgs.dix.OrbStack}/bin/kubectl"
        else "kubectl";
      pinentry = lib.getExe (with pkgs; (
        if stdenv.isDarwin
        then pinentry_mac
        else pinentry-all
      ));
    };
  };
}
