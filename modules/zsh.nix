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
        promptInit = ''
          source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
        '';
        shellInit = ''
          [[ -d $HOME/.cargo ]] && . "$HOME/.cargo/env"
        '';
        loginShellInit = ''
          eval "$(${pkgs.pyenv}/bin/pyenv init -)"
          source $HOME/.orbstack/shell/init.zsh 2>/dev/null || :
          eval "$(${pkgs.fzf}/bin/fzf --zsh)"

          fpath+=(
            ${pkgs.zsh-completions}/share/zsh/site-functions
          )
        '';
        interactiveShellInit = ''
          source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
          source ${pkgs.zsh-dix}/share/zsh/dix.plugin.zsh
          source ${pkgs.zsh-f-sy-h}/share/zsh/site-functions/F-Sy-H.plugin.zsh
          source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
        '';
      };
    };

    environment.etc."zshrc.local".text = ''
      eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
      eval "$(${pkgs.zoxide}/bin/zoxide init --cmd j zsh)"
    '';
  };
}

