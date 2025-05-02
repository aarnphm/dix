# dix

Setting up environment shouldn't be this hard

```bash
# install nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# For debian based systems to setup nvidia run the following:
nix run github:aarnphm/dix#ubuntu-nvidia -- <driver_version>


# build for darwin
nix run nix-darwin -- switch --flake github:aarnphm/dix#appl-mbp16 --show-trace -L
# On Darwin, install additional Raycast, Karabiner-Element

# build for home-manager
nix run home-manager -- switch --flake github:aarnphm/dix#ubuntu --show-trace -L
```

Finally, clone neovim:

```bash
gh repo clone aarnphm/editor $HOME/.config/nvim

ln -s $HOME/.vimrc $HOME/.config/nvim/.vimrc

curl -LsSf https://astral.sh/uv/install.sh | sh
```

TODO:

- [ ] `nix run github:aarnphm/dix -- setup <profile>`
