{ config, lib, pkgs, ... }:
with lib;
{
  options.alacritty = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''alacritty configuration'';
    };
  };

  config = mkIf config.alacritty.enable {
    programs = {
      alacritty = {
        enable = true;
        settings = {
          import = [ "${pkgs.alacritty-theme}/rose-pine.toml" ];
          window = {
            dynamic_padding = false;
            decorations = "buttonless";
            option_as_alt = "Both";
            dimensions = {
              columns = 120;
              lines = 60;
            };
            position = {
              x = 700;
              y = 600;
            };
          };
          scrolling = {
            history = 23040;
          };
          font = {
            size = 15;
            normal = {
              family = "BerkeleyMono Nerd Font Mono";
              style = "Regular";
            };
            bold = {
              family = "BerkeleyMono Nerd Font Mono";
            };
            italic = {
              family = "BerkeleyMono Nerd Font Mono";
            };
            offset = {
              x = 0;
              y = 2;
            };
            glyph_offset = {
              x = -1;
              y = -1;
            };
          };
          bell.animation = "EaseOutExpo";
          cursor = {
            style.shape = "Block";
            vi_mode_style.blinking = "On";
          };
          hints.enabled = [
            {
              command = "open";
              hyperlinks = true;
              post_processing = true;
              persist = false;
              mouse.enabled = true;
              binding = { key = "U"; mods = "Control|Shift"; };
              regex = ''
                (ipfs:|ipns:|magnet:|mailto:|gemini://|gopher://|https://|http://|news:|file:|git://|ssh:|ftp://)[^\u0000-\u001F\u007F-\u009F<>"\\s{-}\\^⟨⟩`]+'';
            }
          ];
        };
      };
    };
  };
}
