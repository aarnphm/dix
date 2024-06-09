{ config, lib, pkgs, ... }:
with lib; let
  concatStringsSepNewLine = iterables: concatStringsSep "\n" iterables;
in
{
  options.zsh = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''Zsh for MacOS'';
    };
  };

  config = mkIf config.zsh.enable {
    programs.zsh = {
      enable = true;
      enableVteIntegration = true;
      historySubstringSearch.enable = true;
      completionInit = concatStringsSepNewLine [
        (optionalString pkgs.stdenv.isLinux "autoload -U compinit && compinit")
        (optionalString pkgs.stdenv.isLinux "autoload -U bashcompinit && bashcompinit")
      ];
      initExtraBeforeCompInit = concatStringsSepNewLine [
        (optionalString pkgs.stdenv.isLinux ''source ${pkgs.gitstatus}/share/gitstatus/gitstatus.prompt.zsh'')
        ''${lib.getExe pkgs.any-nix-shell} zsh --info-right | source /dev/stdin''
      ];
      plugins = [
        {
          name = "fzf-tab";
          src = pkgs.fetchFromGitHub {
            owner = "Aloxaf";
            repo = "fzf-tab";
            rev = "v1.1.2";
            hash = "sha256-Qv8zAiMtrr67CbLRrFjGaPzFZcOiMVEFLg1Z+N6VMhg=";
          };
        }
        {
          name = "F-Sy-H";
          src = pkgs.fetchFromGitHub {
            owner = "z-shell";
            repo = "F-Sy-H";
            rev = "v1.67";
            hash = "sha256-zhaXjrNL0amxexbZm4Kr5Y/feq1+2zW0O6eo9iZhmi0=";
          };
        }
      ];
      initExtraFirst = concatStringsSepNewLine [
        ''source ${pkgs.dix.zsh-dix}/share/zsh/dix.plugin.zsh''
      ];
      envExtra = ''
        [[ -d ${config.home.homeDirectory}/.cargo ]] && . "${config.home.homeDirectory}/.cargo/env"

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
            echo "$stdin" | ${lib.getExe pkgs.bat} --language=sh --plain --number --color=always --wrap=character
            return
          fi

          if [ -d "$realpath" ]; then
            ${lib.getExe  pkgs.tree} -a -I '.DS_Store|.localized' -C "$realpath" | head -100
          elif [ -f "$realpath" ]; then
            mime="$(file -Lbs --mime-type "$realpath")"
            category="''${mime%%/*}"
            if [ "$category" = 'image' ]; then
              # I guessed `60` to be fine for my exact terminal size
              local default_width=$(( "$FZF_PREVIEW_COLUMNS" < 60 ? 60 : "$FZF_PREVIEW_COLUMNS" ))
              ${lib.getExe pkgs.catimg} -r2 -w "$default_width" "$realpath"
            elif [[ "$mime" =~ 'binary' ]]; then
              ${lib.getExe pkgs.hexyl} --length 5KiB --border none --terminal-width "$FZF_PREVIEW_COLUMNS" "$realpath"
            else
              ${lib.getExe pkgs.bat} --number --color=always "$realpath"
            fi
          else
            # This is not a directory and not a file, just print the string.
            echo "$realpath" | fold -w "$FZF_PREVIEW_COLUMNS"
          fi
        }
      '';
      profileExtra =
        let
          sites = [
            "${pkgs.dix.zsh-dix}/share/zsh/site-functions"
            "${pkgs.zsh-completions}/share/zsh/site-functions"
            (optionalString pkgs.stdenv.isDarwin "${pkgs.dix.OrbStack}/Applications/OrbStack.app/Contents/Resources/completions/zsh")
          ];
        in
        concatStringsSepNewLine [
          ''eval "$(${lib.getExe pkgs.pyenv} init -)"''
          (concatStrings (map
            (sitePath: ''
              fpath+=${sitePath}
            '')
            sites))
        ];
    };
  };
}
