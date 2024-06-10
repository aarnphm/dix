# dix

```bash
# install nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# depending on macOS or general setup, then install either nix-darwin or home-manager

# build for darwin
nix run nix-darwin -- switch --flake .#appl-mbp16
darwin-rebuild switch --flake ".#appl-mbp16"

# build for home-manager
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update

home-manager switch --flake ".#paperspace"
```
