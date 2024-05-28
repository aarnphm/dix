{ config, pkgs, ... }:
{
  home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${pkgs.nvim-config}";
}
