{ pkgs, homePrefix, user, lib, ... }:
let
  packages = import ./packages.nix { inherit pkgs lib; };
  variables = import ./variables.nix { inherit pkgs lib; };
  pubkeys = import ./pubkeys.nix { };

  age = {
    identityPaths = [ "${homePrefix}/${user}/.pubkey.txt" ];
    secrets = {
      id_ed25519-github = {
        file = ../secrets/${user}-id_ed25519-github.age;
        path = "${homePrefix}/${user}/.ssh/id_ed25519-github";
        owner = user;
        mode = "700";
        group = if pkgs.stdenv.isDarwin then "staff" else user;
      };
      id_ed25519-paperspace = lib.optionalAttrs pkgs.stdenv.isDarwin {
        file = ../secrets/aarnphm-id_ed25519-paperspace.age;
        path = "/Users/aarnphm/.ssh/id_ed25519-paperspace";
        owner = "aarnphm";
        mode = "700";
        group = "staff";
      };
    };
  };
in
{
  inherit pubkeys age;

  darwinModules = {
    inherit age;
    environment = {
      inherit variables;
      systemPackages = packages;
    };
  };

  homeManagerModules = lib.optionalAttrs pkgs.stdenv.isLinux
    {
      home = {
        inherit packages;
        sessionVariables = variables;
      };
    } // {
    inherit age;
  };
}
