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
        completionInit = if pkgs.stdenv.isDarwin then "" else ''
          autoload -U compinit && compinit
          autoload -U bashcompinit && bashcompinit
        '';
        initExtraBeforeCompInit = ''
          source ${pkgs.gitstatus}/share/gitstatus/gitstatus.prompt.zsh
          ${pkgs.any-nix-shell}/bin/any-nix-shell zsh --info-right | source /dev/stdin
        '';
        initExtra = (if pkgs.stdenv.isLinux then ''
          eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
        '' else "") + ''
          source ${pkgs.dix.zsh-dix}/share/zsh/dix.plugin.zsh
          eval "$(${pkgs.zoxide}/bin/zoxide init --cmd j zsh)"

          source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
          source ${pkgs.zsh-f-sy-h}/share/zsh/site-functions/F-Sy-H.plugin.zsh
          source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
        '';
        envExtra = ''
          [[ -d $HOME/.cargo ]] && . "$HOME/.cargo/env"

          zmodload zsh/mapfile
          bwpassfile="${config.home.homeDirectory}/bw.pass"
          if [[ -f "$bwpassfile" ]]; then
            bitwarden=("''${(f@)mapfile[$bwpassfile]}")
            export BW_MASTER=$bitwarden[1]
            export BW_CLIENTID=$bitwarden[2]
            export BW_CLIENTSECRET=$bitwarden[3]
          fi

          _fzf_complete_realpath() {
            # Can be customized to behave differently for different objects.
            local realpath="''${1:--}"  # read the first arg or stdin if arg is missing

            if [ "$realpath" = '-' ]; then
              # It is a stdin, always a text content:
              local stdin="$(< /dev/stdin)"
              echo "$stdin" | ${pkgs.bat.out}/bin/bat \
                --language=sh \
                --plain \
                --number \
                --color=always \
                --wrap=character
              return
            fi

            if [ -d "$realpath" ]; then
              ${pkgs.tree.out}/bin/tree -a -I '.DS_Store|.localized' -C "$realpath" | head -100
            elif [ -f "$realpath" ]; then
              mime="$(file -Lbs --mime-type "$realpath")"
              category="''${mime%%/*}"
              if [ "$category" = 'image' ]; then
                # I guessed `60` to be fine for my exact terminal size
                local default_width=$(( "$FZF_PREVIEW_COLUMNS" < 60 ? 60 : "$FZF_PREVIEW_COLUMNS" ))
                ${pkgs.catimg.out}/bin/catimg -r2 -w "$default_width" "$realpath"
              elif [[ "$mime" =~ 'binary' ]]; then
                ${pkgs.hexyl.out}/bin/hexyl --length 5KiB \
                  --border none \
                  --terminal-width "$FZF_PREVIEW_COLUMNS" \
                  "$realpath"
              else
                ${pkgs.bat.out}/bin/bat --number --color=always "$realpath"
              fi
            else
              # This is not a directory and not a file, just print the string.
              echo "$realpath" | fold -w "$FZF_PREVIEW_COLUMNS"
            fi
          }
        '';
        profileExtra = ''
          eval "$(${pkgs.pyenv}/bin/pyenv init -)"

          fpath+=(
            ${pkgs.zsh-completions}/share/zsh/site-functions
          )
        '' + (if pkgs.stdenv.isDarwin then ''
          fpath+=(
            ${pkgs.dix.OrbStack}/Applications/OrbStack.app/Contents/Resources/completions/zsh
          )
        '' else "");
      };
    };
  };
}
