{ pkgs, lib, ... }:
let
  systemPackages = import ./packages.nix { inherit pkgs lib; };
  variables = import ./variables.nix { inherit pkgs lib; };
in
{
  environment = {
    systemPackages = systemPackages;
    variables = variables;
  };
}
