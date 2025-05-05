# dix

Setting up environment shouldn't be this hard

## installations.

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

nix run github:aarnphm/dix#setup -- darwin # or ubuntu
nix run github:aarnphm/dix#lambda -- --help # Run CLI to interact with Lambda Cloud
```
