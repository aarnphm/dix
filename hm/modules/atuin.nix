{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options.atuin = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''atuin configuration'';
    };
  };

  config = mkIf config.atuin.enable {
    programs.atuin = {
      enable = true;
      package = pkgs.atuin;
      flags = ["--disable-up-arrow"];
      enableZshIntegration = true;
      settings = {
        keymap_mode = "vim-insert";
        auto_sync = true;
        sync_frequency = "30m";
        style = "compact";
      };
    };
  };
}
