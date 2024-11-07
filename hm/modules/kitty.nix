{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  theme =
    if config.home.sessionVariables.XDG_SYSTEM_THEME == "dark"
    then "rose-pine"
    else "rose-pine-dawn";
  family = "BerkeleyMono Nerd Font Mono"; # "BerkeleyMono Nerd Font Mono" | "JetBrainsMono NFM"
in {
  options.kitty = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''kitty configuration'';
    };
  };

  config = mkIf config.kitty.enable {
    programs = {
      kitty = {
        enable = true;
        themeFile = theme;
        font = {
          name = family;
          size = 14;
        };
        keybindings = {
          "ctrl+[" = "layout_action : decrease_num_full_size_windows";
          "ctrl+]" = "layout_action : increase_num_full_size_windows";
          "kitty_mod+h" = "neighboring_window : left";
          "kitty_mod+l" = "neighboring_window : right";
          "kitty_mod+k" = "neighboring_window : up";
          "kitty_mod+j" = "neighboring_window : down";
        };
        settings = {
          force_ltr = "yes";
          adjust_line_height = 0;
          adjust_column_width = 0;
          disable_ligatures = "never";
          cursor_shape = "block";
          cursor_beam_thickness = "1.5";
          cursor_underline_thickness = 2.0;
          scrollback_lines = 20000;
          hide_window_decorations = "yes";
          kitty_mod = "cmd+option";
          macos_titlebar_color = "system";
          macos_window_resizable = "yes";
          open_url_with = "default";
          url_prefixes = "http https file ftp";
          clipboard_control = "write-clipboard write-primary";
        };
      };
    };
  };
}
