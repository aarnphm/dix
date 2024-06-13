{ config, lib, pkgs, ... }:
with lib;
let
  gpgAgentConfig = enableTouchId: pkgs.writeText "gpg-agent.conf" (lib.concatStringsSep "\n" [
    "default-cache-ttl 600"
    "max-cache-ttl 7200"
    "allow-loopback-pinentry"
    "pinentry-program ${lib.getExe (if enableTouchId then pkgs.dix.pinentry-touchid else pkgs.pinentry_mac)}"
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

  config = mkIf config.gpg.enable
    {
      programs.gpg = {
        enable = true;
        settings = {
          auto-key-retrieve = true;
          no-emit-version = true;
          no-comments = false;
          # keyserver = "hkps://keys.openpgp.org";
        };
        scdaemonSettings = {
          log-file = "/tmp/${config.home.username}_scdaemon.log";
          disable-ccid = true;
        };
      };

      home.file.".gnupg/gpg-agent.conf".source = gpgAgentConfig true;
    } // lib.optionalAttrs pkgs.stdenv.isLinux {
    services.gpg-agent = {
      enable = true;
      enableSSHSupport = true;
      verbose = true;
      defaultCacheTtl = 600;
      maxCacheTtl = 7200;
      pinentryPackage = pkgs.pinentry-all;
      extraConfig = ''
        allow-loopback-pinentry
      '';
    };
  };
}
