{
  writeProgram,
  coreutils,
  gh,
  rustup,
  lib,
  stdenv,
  makeWrapper,
  bash,
  nix,
  git,
  jq,
  profile ? "/nix/var/nix/profiles/system",
  # This should be kept in sync with the default
  # `environment.systemPath`. We err on side of including conditional
  # things like the profile directories, since they’re more likely to
  # help than hurt, and this default is mostly used for fresh
  # installations anyway.
  systemPath ?
    lib.concatStringsSep ":" [
      "$HOME/.nix-profile/bin"
      "/etc/profiles/per-user/$USER/bin"
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
      "/usr/local/bin"
      "/usr/bin"
      "/bin"
      "/usr/sbin"
      "/sbin"
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
    ],
  # This should be kept in sync with the default `nix.nixPath`.
  nixPath ?
    lib.concatStringsSep ":" [
      "darwin-config=/etc/nix-darwin/configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ],
}: let
  extraPath = lib.makeBinPath [rustup bash gh jq nix git coreutils];
  path = "${extraPath}:${systemPath}";
in {
  bootstrap =
    writeProgram "bootstrap" {
      replacements = {
        inherit path nixPath profile;
        inherit (stdenv) shell;
        FLAKE_URI_BASE = "github:aarnphm/dix";
      };
    }
    ./bootstrap.sh;
}
