{
  config,
  lib,
  ...
}:
with lib; {
  options.direnv = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''direnv configuration'';
    };
  };

  config = mkIf config.direnv.enable {
    programs.direnv = {
      enable = true;
      enableFishIntegration = false;
      config = {
        global = {
          load_dotenv = true;
          strict_env = true;
        };
      };
    };
  };
}
