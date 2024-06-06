{ config, lib, pkgs, ... }:
with lib;
{
  options.zsh = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''Zsh for MacOS'';
    };
  };

  config = mkIf config.zsh.enable {
    programs = {
      zsh = {
        enable = true;
        enableFzfHistory = true; # ctrl-r
        enableFzfCompletion = true;
        promptInit = ''
          source ${pkgs.gitstatus}/share/gitstatus/gitstatus.prompt.zsh
          ${pkgs.any-nix-shell}/bin/any-nix-shell zsh --info-right | source /dev/stdin
        '';
        shellInit = ''
          [[ -d $HOME/.cargo ]] && . "$HOME/.cargo/env"
        '';
        loginShellInit = ''
          eval "$(${pkgs.pyenv}/bin/pyenv init -)"
          source $HOME/.orbstack/shell/init.zsh 2>/dev/null || :

          fpath+=(
            ${pkgs.zsh-completions}/share/zsh/site-functions
            ${pkgs.zsh-dix}/share/zsh/site-functions
          )
        '';
        interactiveShellInit = ''
          source ${pkgs.zsh-dix}/share/zsh/dix.plugin.zsh
        '';
      };
    };

    environment.etc."zshrc.local".text = ''
      eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
      eval "$(${pkgs.zoxide}/bin/zoxide init --cmd j zsh)"

      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
      source ${pkgs.zsh-f-sy-h}/share/zsh/site-functions/F-Sy-H.plugin.zsh
      source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
    '';
  };
}

