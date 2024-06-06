{ config, pkgs, ... }:
{
  home.file.".config/nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "${pkgs.vimPlugins.vim-nix}";
    recursive = true;
  };
  home.file.".fzfrc".text = ''
    --prompt='» ' --marker='»' --pointer='◆' --info=right --layout='reverse' --border='sharp' --preview-window='border-sharp' --height='80%'
  '';
  home.file.".zshenv".text = ''
    _fzf_complete_realpath () {
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
          --wrap=character \
          --terminal-width="$FZF_PREVIEW_COLUMNS" \
          --line-range :100
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
          ${pkgs.bat.out}/bin/bat --number \
            --color=always \
            --line-range :100 \
            "$realpath"
        fi
      else
        # This is not a directory and not a file, just print the string.
        ${pkgs.eza.out}/bin/eza -1 --color=always "$realpath" | fold -w "$FZF_PREVIEW_COLUMNS"
      fi
    }
  '';
  home.file.".config/git" = {
    source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/git";
    recursive = true;
  };
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


