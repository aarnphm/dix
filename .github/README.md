# dix

Setting up environment shouldn't be this hard

## installations.

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

nix run github:aarnphm/dix#bootstrap -- darwin # or ubuntu
nix run github:aarnphm/dix#lambda -- --help # Run CLI to interact with Lambda Cloud
```

I'm using atuin to manage shell history, some custom fzf with zsh, rg + neovim + fd + nix to manage setup across multiple systems.

## notes.

I also include a few standalone tools that can be installed, such as `lambda`.

### lambda.

If you don't use Nix or only need the `lambda` tool, you can install it directly:

```bash
curl -sSfL https://raw.githubusercontent.com/aarnphm/dix/main/install.sh | bash
```

This will default to check whether `nix` is available on your system, and thus recommends the default `nix` way to install this binary.
However, if you wish to bypass this check, do the following:

```bash
curl -sSfL https://raw.githubusercontent.com/aarnphm/dix/main/install.sh | bash -s -- --force-install
```
