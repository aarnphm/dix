{ config, pkgs, ... }:
{
  home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nvim-config}";
  home.file.".config/git".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/git";
  home.file.".config/alacritty".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/alacritty";
  home.file.".config/wezterm".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/wezterm";
  home.file.".config/kitty".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/kitty";
  home.file.".config/sketchybar".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/sketchybar";
  home.file.".config/zed/keymap.json".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/zed/keymap.json";
  home.file.".config/zed/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.emulators}/zed/settings.json";
}
