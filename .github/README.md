# dix

Setting up environment shouldn't be this hard

```bash
# install nix
# For MacOS Sequoia, the following environment variable should be set: NIX_INSTALLER_NIX_BUILD_USER_ID_BASE=400
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install


# build for darwin
nix run nix-darwin -- switch --flake github:aarnphm/dix#appl-mbp16

# build for home-manager
nix run home-manager -- switch --flake github:aarnphm/dix#paperspace
```

TODO:
- [ ] nix run github:aarnphm/dix -- setup <profile>


