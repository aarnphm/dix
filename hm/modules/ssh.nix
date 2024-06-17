{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options.ssh = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = mdDoc ''ssh home configuration'';
    };
  };

  config = mkIf config.ssh.enable {
    programs.ssh =
      {
        enable = true;
        compression = true;
        addKeysToAgent = "yes";
        extraOptionOverrides = {
          Ciphers = "aes128-ctr,aes192-ctr,aes256-ctr";
          ForwardX11 = "yes";
        };
        matchBlocks =
          {
            "github.com" = {
              identityFile = ''${config.home.homeDirectory}/.ssh/id_ed25519-github'';
            };
          }
          // lib.optionalAttrs pkgs.stdenv.isDarwin {
            "a100" = {
              hostname = "184.105.208.165";
              user = "paperspace";
              identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519-paperspace";
            };
          };
      }
      // lib.optionalAttrs pkgs.stdenv.isDarwin {
        extraConfig = ''
          IgnoreUnknown UseKeychain
          UseKeychain yes
        '';
        includes = [
          "${config.home.homeDirectory}/.orbstack/ssh/config"
        ];
      };
  };
}
