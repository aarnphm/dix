{
  writeShellApplication,
  coreutils,
  git,
  gh,
  nix,
  rustup,
}:
writeShellApplication {
  name = "bootstrap";
  runtimeInputs = [coreutils git gh nix rustup];
  text = ''
    #!/usr/bin/env bash
    set -euo pipefail

    usage() {
      echo "Usage: $0 <darwin|ubuntu>"
    }

    if [ "$#" -ne 1 ]; then
      usage
      exit 1
    fi

    PROFILE="$1"

    case "$PROFILE" in
      darwin)
        echo "Running nix-darwin switch for appl-mbp16..."
        nix run nix-darwin/master#darwin-rebuild -- switch --flake github:aarnphm/dix#appl-mbp16 -v --show-trace -L
        ;;
      ubuntu)
        echo "Running home-manager switch for ubuntu..."
        nix run home-manager -- switch --flake github:aarnphm/dix#ubuntu -v --show-trace -L
        ;;
      *)
        usage
        exit 1
        ;;
    esac

    if ! gh auth status &>/dev/null; then
      echo "Logging into GitHub via gh..."
      gh auth login -p ssh
    fi

    if command -v rustup &>/dev/null; then
      if ! rustup toolchain list | grep -q nightly; then
        echo "Installing Rust nightly toolchain..."
        rustup toolchain install nightly
      fi
    else
      echo "rustup not found, skipping Rust nightly installation."
    fi

    NVIM_DIR="$HOME/.config/nvim"
    if [ ! -d "$NVIM_DIR" ]; then
      echo "Cloning Neovim configuration..."
      gh repo clone aarnphm/editor "$NVIM_DIR"
    fi

    if [ -f "$HOME/.vimrc" ] && [ ! -L "$NVIM_DIR/.vimrc" ]; then
      echo "Linking .vimrc into Neovim configuration..."
      ln -s "$HOME/.vimrc" "$NVIM_DIR/.vimrc"
    fi

    echo "Setup completed."
  '';
}
