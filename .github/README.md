# dix

Setting up environment shouldn't be this hard

```bash
# install nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --nix-build-user-id-base 400


# build for darwin
nix run nix-darwin -- switch --flake github:aarnphm/dix#appl-mbp16
# On Darwin, install additional Raycast, Karabiner-Element

# build for home-manager
nix run home-manager -- switch --flake github:aarnphm/dix#paperspace
```

TODO:

- [ ] `nix run github:aarnphm/dix -- setup <profile>`
