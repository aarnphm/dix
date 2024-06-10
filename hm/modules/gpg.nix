{ config, lib, pkgs, ... }:
with lib; (
  let
    gpgAgentConfig = pkgs.writeText "gpg-agent.conf" (lib.concatStringsSep "\n" [
      "default-cache-ttl 600"
      "max-cache-ttl 7200"
      (lib.optionalString pkgs.stdenv.isDarwin ''
        pinentry-program ${pkgs.dix.pinentry-touchid}/bin/pinentry-touchid
      '')
    ]);
  in
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
          keyserver = "hkps://keys.openpgp.org";
        };
        scdaemonSettings = {
          log-file = "/tmp/${config.home.username}_scdaemon.log";
          disable-ccid = true;
        };
      };

      home.file.".gnupg/gpg-agent.conf".source = gpgAgentConfig;
    };
  }
)
