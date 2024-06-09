{ config, lib, ... }:
with lib; {
  options.zoxide = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''zoxide configuration'';
    };
  };

  config = mkIf config.zoxide.enable {
    programs.zoxide = {
      enable = true;
      options = [ "--cmd j" ];
    };
  };
}
