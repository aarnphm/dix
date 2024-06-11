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

  config = mkIf config.system.enable (
    let
      dix = pkgs.dix;
    in
    {
      home.file.".vimrc".source = config.lib.file.mkOutOfStoreSymlink "${dix.editor}/.vimrc";
      xdg = {
        enable = true;
        configFile = {
          "nvim" = {
            source = config.lib.file.mkOutOfStoreSymlink "${dix.editor}";
            recursive = true;
          };
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
    }
  );
}
