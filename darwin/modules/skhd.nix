{ config, lib, pkgs, ... }:
with lib;
{
  options.skhd = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''
        Simple Hotkey Daemon for MacOS
      '';
    };
  };

  config = mkIf config.skhd.enable {
    services = {
      skhd = {
        enable = true;
        package = pkgs.skhd;
        skhdConfig = ''
          ctrl + cmd - 0x11: ${pkgs.alacritty}/Applications/Alacritty.app/Contents/MacOS/alacritty
        '';
      };
    };
    system = {
      keyboard = {
        enableKeyMapping = true;
      };
    };
  };
}
