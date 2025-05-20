{
  config,
  lib,
  ...
}:
with lib; {
  options.broot = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''broot configuration'';
    };
  };

  config = mkIf config.broot.enable {
    programs = {
      broot = {
        enable = true;
        enableZshIntegration = true;
        settings = {
          modal = true;
          default_flags = "-g";
          syntax_theme =
            if config.home.sessionVariables.XDG_SYSTEM_THEME == "dark"
            then "OceanDark"
            else "OceanLight";
          icon_theme = "nerdfont";
          special_paths = {
            ".git" = {
              show = "never";
              list = "never";
            };
            "~/.config" = {
              show = "always";
              list = "always";
            };
          };
          transformers = [
            {
              input_extensions = ["pdf"];
              output_extension = "png";
              mode = "image";
              command = ["mutool" "draw" "-w" "1000" "-o" "{output-path}" "{input-path}"];
            }
            {
              input_extensions = ["json"];
              output_extension = "json";
              mode = "text";
              command = ["jq"];
            }
          ];
          verbs = [
            {
              name = "open";
              key = "enter";
              execution = "$EDITOR {file}";
              working_dir = "{root}";
              leave_broot = true;
            }
          ];
        };
      };
    };
  };
}
