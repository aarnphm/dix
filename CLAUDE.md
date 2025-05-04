## dix rules

We uses nix with flake enabled, and nix-darwin + home-manager to manage tooling across distros

## Build Commands

- Build:
  - Darwin: `nix run nix-darwin/master#darwin-rebuild -- switch --flake ".#appl-mbp16" -v --show-trace -L`
  - Linux: `nix run home-manager -- switch --flake .#ubuntu --show-trace -L`
