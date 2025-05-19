## detachtools rules

We use nix with flake enabled, and nix-darwin + home-manager to manage tooling across distros
We use alejandra and statix for format and lint respectively.

## Commands

Build commands:

- Darwin: `nix run nix-darwin/master#darwin-rebuild -- switch --flake ".#appl-mbp16" -v --show-trace -L`
- Linux: `nix run home-manager -- switch --flake .#ubuntu --show-trace -L`

Make sure to keep comments to the minimum, no need to include explanation if variables are descriptive enough.

Also we should always use camelCase for variables, snake-case for defining packages.
