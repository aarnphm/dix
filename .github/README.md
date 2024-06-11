# dix

Setting up environment shouldn't be this hard

```bash
# install nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# depending on macOS or general setup, then install either nix-darwin or home-manager

# build for darwin
nix run nix-darwin -- switch --flake github:aarnphm/dix#appl-mbp16

# build for home-manager
nix run home-manager -- switch --flake github:aarnphm/dix#paperspace
```
