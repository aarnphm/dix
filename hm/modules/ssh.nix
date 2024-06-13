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
              identityFile = ''/run${lib.optionalString pkgs.stdenv.isLinux "/user/1000"}/agenix/id_ed25519-github'';
            };
          }
          // lib.optionalAttrs pkgs.stdenv.isDarwin {
            "a4000" = {
              hostname = "184.105.106.53";
              user = "paperspace";
              identityFile = "/run/agenix/id_ed25519-paperspace";
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
