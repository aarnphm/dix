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
              setEnv = {
                TERM = ''xterm-256color'';
              };
            };
            "h100" = {
              hostname = "184.105.157.234";
              user = "paperspace";
              identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519-paperspace";
              setEnv = {
                TERM = ''xterm-256color'';
              };
            };
            "sam-wafer" = {
              hostname = "75.10.7.20";
              user = "sam";
              identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519-wafer";
              setEnv = {
                TERM = ''xterm-256color'';
              };
            };
            "se3db3" = {
              hostname = "se3db3.cas.mcmaster.ca";
              user = "phama10";
              setEnv = {
                TERM = ''xterm-256color'';
              };
            };
            "gitlab.cas.mcmaster.ca" = {
              identityFile = ''${config.home.homeDirectory}/.ssh/id_ed25519-mcmaster'';
              setEnv = {
                TERM = ''xterm-256color'';
              };
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
