{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options.neovim = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''neovim configuration'';
    };
  };

  config = mkIf config.neovim.enable {
    programs.neovim = {
      enable = true;
      package = pkgs.neovim;
      extraLuaPackages = ps: with ps; [magick luacheck];
      vimAlias = true;
      withPython3 = true;
      defaultEditor = true;
      extraPackages = [pkgs.imagemagick];
      extraPython3Packages = ps: with ps; [mypy jupyter_client];
    };
  };
}
