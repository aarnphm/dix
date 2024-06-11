{ config, lib, pkgs, ... }:
with lib;
{
  options.ssh = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''ssh home configuration'';
    };
  };

  config = mkIf config.ssh.enable {
    programs.ssh = lib.recursiveUpdate
      {
        enable = true;
        compression = true;
        addKeysToAgent = "yes";
        extraOptionOverrides = {
          Ciphers = "aes128-ctr,aes192-ctr,aes256-ctr";
          ForwardX11 = "yes";
        };
        matchBlocks = {
          "a4000" = {
            hostname = "184.105.106.53";
            user = "paperspace";
            identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519-paperspace";
          };
          "github.com" = {
            identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519-github";
          };
        };
      }
      (if pkgs.stdenv.isDarwin then
        {
          extraConfig = ''
            IgnoreUnknown UseKeychain
            UseKeychain yes
          '';
          includes = [
            "${config.home.homeDirectory}/.orbstack/ssh/config"
          ];
        } else { }
      );
  };
}
