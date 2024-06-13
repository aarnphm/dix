{ pkgs, homePrefix, user, lib, ... }:
let
  packages = import ./packages.nix { inherit pkgs lib; };
  variables = import ./variables.nix { inherit pkgs lib; };
  pubkeys = import ./pubkeys.nix { };


  identityPaths = [ "${homePrefix}/${user}/.pubkey.txt" ];
  darwinAge = {
    inherit identityPaths;
    secrets = {
      id_ed25519-github = {
        file = ../secrets/${user}-id_ed25519-github.age;
        path = "${homePrefix}/${user}/.ssh/id_ed25519-github";
        owner = user;
        mode = "700";
        group = "staff";
      };
      id_ed25519-paperspace = {
        file = ../secrets/${user}-id_ed25519-paperspace.age;
        path = "${homePrefix}/${user}/.ssh/id_ed25519-paperspace";
        owner = user;
        mode = "700";
        group = "staff";
      };
    };
  };
  linuxAge = {
    inherit identityPaths;
    secrets = {
      id_ed25519-github = {
        file = ../secrets/paperspace-id_ed25519-github.age;
        path = "${homePrefix}/${user}/.ssh/id_ed25519-github";
      };
    };
  };
in
{
  inherit pubkeys;

  darwinModules = {
    age = darwinAge;
    environment = {
      inherit variables;
      systemPackages = packages;
    };
  };

  homeManagerModules = lib.optionalAttrs pkgs.stdenv.isLinux
    {
      age = linuxAge;
      home = {
        inherit packages;
        sessionVariables = variables;
      };
    };
}
