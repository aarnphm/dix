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
          source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
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
          )
        '';
        interactiveShellInit = ''
          source ${pkgs.zsh-dix}/share/zsh/dix.plugin.zsh

          # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
          # Initialization code that may require console input (password prompts, [y/n]
          # confirmations, etc.) must go above this block; everything else may go below.
          if [[ -r "$${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$${(%):-%n}.zsh" ]]; then
            source "$${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-$${(%):-%n}.zsh"
          fi
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

