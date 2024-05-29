{ config, lib, pkgs, ... }:
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
          layout = "float";
          auto_balance = "off";
          split_ratio = "0.50";
          window_border = "on";
          window_border_width = "2";
          window_placement = "first_child";
          focus_follows_mouse = "off";
          mouse_follows_focus = "autoraise";
          top_padding = "5";
          bottom_padding = "5";
          left_padding = "5";
          right_padding = "5";
          window_gap = "5";
          menubar_opacity = "0.0";
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
