{ pkgs, lib, ... }:
{
  packages = import ./packages.nix { inherit pkgs lib; };
  variables = import ./variables.nix { inherit pkgs lib; };
}
