{ config, pkgs, ... }:
{
  home.file.".config/git" = {
    source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/git";
    recursive = true;
  };
  home.file.".config/alacritty" = {
    source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/alacritty";
    recursive = true;
  };
  home.file.".config/wezterm" = {
    source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/wezterm";
    recursive = true;
  };
  home.file.".config/kitty" = {
    source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/kitty";
    recursive = true;
  };
  home.file.".config/zed/keymap.json".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/zed/keymap.json";
  home.file.".config/zed/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/zed/settings.json";
}
