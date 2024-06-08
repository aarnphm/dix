{ config, lib, pkgs, ... }:
with lib;
{
  options.system = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''system home configuration'';
    };
  };

  config = mkIf config.system.enable {
    xdg = {
      enable = true;
      configFile = {
        "nvim" = {
          source = config.lib.file.mkOutOfStoreSymlink "${pkgs.editor}";
          recursive = true;
        };
        "zed/keymap.json".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/zed/keymap.json";
        "zed/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/zed/settings.json";
      };
    };
    editorconfig = {
      enable = true;
      settings = {
        "*" = {
          end_of_line = "lf";
          charset = "utf-8";
          trim_trailing_whitespace = true;
          indent_style = "space";
          indent_size = 2;
          max_line_width = 119;
        };
        "/node_modules/*" = {
          indent_size = "unset";
          indent_style = "unset";
        };
        "{package.json,.travis.yml,.eslintrc.json}" = {
          indent_style = "space";
        };
      };
    };
  };
}
