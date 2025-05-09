{
  config,
  lib,
  ...
}:
with lib; {
  options.gpg = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc "GPG Settings for MacOS";
    };
  };

  config = mkIf config.gpg.enable {
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };
}
