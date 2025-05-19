# dix

Setting up environment shouldn't be this hard

## installations.

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

nix run github:aarnphm/dix#bootstrap -- darwin # or ubuntu
nix run github:aarnphm/dix#lambda -- --help # Run CLI to interact with Lambda Cloud
```

Stack:

- atuin to manage shell history
- gh + git + eza
- fzf + zsh + rg + neovim + fd + nix to manage setup across multiple systems.

## bootstrap.

bootstrap is a helper to run a few tools on setup or rebuild based on Linux/Darwin. It is a wrapper around nix-darwin/home-manager functionality, albeit it behaves somewhat the same with a few additional flags/optimization.
Ofc you can just run `nix run home-manager` or `nix run nix-darwin/master#darwin-rebuild`, but I'm lazy...

```bash
nix run github:aarnphm/dix#bootstrap -- <darwin|ubuntu> --flake ~/workspace/dix # or any flake uri
```

## notes.

I also include some standalone tools that can be installed, such as `lambda`.

Some packages include certain override:

- `gvim`: This will add support for remote via `--address`. More information with `gvim -h`

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
