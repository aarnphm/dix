{ pkgs, lib, ... }:
let
  packages = import ./packages.nix { inherit pkgs lib; };
  variables = import ./variables.nix { inherit pkgs lib; };
in
{
  darwinModules = {
    environment = {
      inherit variables;
      systemPackages = packages;
    };
  };

  homeManagerModules = lib.optionalAttrs pkgs.stdenv.isLinux {
    home = {
      inherit packages;
      sessionVariables = variables;
    };
  };
}
