{ config, lib, ... }:
with lib;
{
  options.gpg = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''gpg home configuration'';
    };
  };

  config = mkIf config.gpg.enable {
    programs.gpg = {
      enable = true;
      settings = {
        auto-key-retrieve = true;
        no-emit-version = true;
        no-comments = false;
      };
    };
  };
}
