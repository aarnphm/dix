{ config, lib, pkgs, ... }:
with lib;
{
  options.bat = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''bat configuration'';
    };
  };

  config = mkIf config.bat.enable {
    programs = {
      bat = {
        enable = true;
        extraPackages = with pkgs.bat-extras; [ batwatch batpipe batman batgrep batdiff ];
        config = {
          theme = "GitHub";
          map-syntax = [
            ".ignore:Git Ignore"
            "config:Git Config"
          ];
          pager = "${lib.getExe pkgs.less} --RAW-CONTROL-CHARS --quit-if-one-screen --mouse";
        };
      };
    };
  };
}
