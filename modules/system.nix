{ pkgs, lib, ... }: {
  # variables
  environment.variables = import ./variables.nix { inherit pkgs lib; };
  # packages
  environment.systemPackages = import ./packages.nix { inherit pkgs; };
}
