{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  theme =
    if config.home.sessionVariables.XDG_SYSTEM_THEME == "dark"
    then "${pkgs.alacritty-theme}/rose-pine.toml"
    else "${pkgs.alacritty-theme}/rose-pine-dawn.toml";
  family = "BerkeleyMono Nerd Font Mono"; # "BerkeleyMono Nerd Font Mono" | "JetBrainsMono NFM"
in {
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
          import = [theme];
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
          env = {
            TERM = "xterm-256color";
          };
          scrolling = {
            history = 30000;
          };
          font = {
            size = 16;
            normal = {
              family = family;
              style = "Regular";
            };
            bold = {
              family = family;
            };
            italic = {
              family = family;
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
          keyboard.bindings = [
            {
              key = "T";
              mods = "Command";
              chars = "\×80\xfc\x80t";
            }
            {
              key = "LBracket";
              mods = "Command";
              chars = "\×80\xfc\×80[";
            }
            {
              key = "RBracket";
              mods = "Command";
              chars = "\×80\xfc\×80]";
            }
          ];
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
              binding = {
                key = "U";
                mods = "Control|Shift";
              };
              regex = ''
                (ipfs:|ipns:|magnet:|mailto:|gemini://|gopher://|https://|http://|news:|file:|git://|ssh:|ftp://)[^\u0000-\u001F\u007F-\u009F<>"\\s{-}\\^⟨⟩`]+'';
            }
          ];
        };
      };
    };
  };
}
