{ config, lib, ... }:
with lib;
{
  options.yabai = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Tiling Window Manager for MacOS
      '';
    };
  };

  config = mkIf config.yabai.enable {
    services = {
      yabai = {
        enable = true;
        enableScriptingAddition = true;
        config = {
          layout = "bsp";
          auto_balance = "off";
          split_ratio = "0.50";
          window_border = "off";
          window_border_width = "2";
          window_placement = "second_child";
          focus_follows_mouse = "off";
          mouse_follows_focus = "autoraise";
          top_padding = "5";
          bottom_padding = "5";
          left_padding = "5";
          right_padding = "5";
          window_gap = "10";
          menubar_opacity = "1.0";
        };
        extraConfig = ''
          yabai -m window --focus east
          yabai -m rule --add title='^(Opening)' manage=off layer=above
          yabai -m rule --add app='Notion' manage=off layer=above
          yabai -m rule --add title="(Copy|Bin|About This Mac|Info)" manage=off
          yabai -m rule --add app="^(Calculator|System Settings|System Preferences|System Information|Activity Monitor|[sS]tats|yabai|[Jj]et[Bb]rains [Tt]ool[Bb]ox)$" manage=off
        '';
      };
    };
  };
}
