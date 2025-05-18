#! @shell@

set -euo pipefail

usage() {
	echo "Usage: @pname@ <darwin|linux> [target_name]"
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	usage
	exit 1
fi

SYSTEM_TYPE="$1"
TARGET_NAME="${2:-}"

FLAKE_TARGET=""

case "$SYSTEM_TYPE" in
darwin)
	if [ -z "$TARGET_NAME" ]; then
		FLAKE_TARGET="appl-mbp16"
	else
		FLAKE_TARGET="$TARGET_NAME"
	fi
	echo "Running nix-darwin switch for $FLAKE_TARGET..."
	SUDO_USER=aarnphm @nix@ run nix-darwin/master#darwin-rebuild -- switch --flake "@FLAKE_URI_BASE@#''${FLAKE_TARGET}" -v --show-trace -L
	;;
linux)
	if [ -z "$TARGET_NAME" ]; then
		FLAKE_TARGET="ubuntu"
	else
		FLAKE_TARGET="$TARGET_NAME"
	fi
	echo "Running home-manager switch for $FLAKE_TARGET..."
	@nix@ run home-manager -- switch --flake "@FLAKE_URI_BASE@#''${FLAKE_TARGET}" -v --show-trace -L
	;;
*)
	usage
	exit 1
	;;
esac

if ! @gh@ auth status &>/dev/null; then
	echo "Logging into GitHub via gh..."
	@gh@ auth login -p ssh
fi

if ! @rustup@ toolchain list | grep -q nightly; then
	echo "Installing Rust nightly toolchain..."
	@rustup@ toolchain install nightly
fi

NVIM_DIR="$HOME/.config/nvim"
if [ ! -d "$NVIM_DIR" ]; then
	echo "Cloning Neovim configuration..."
	@gh@ repo clone aarnphm/editor "$NVIM_DIR"
fi

if [ -f "$HOME/.vimrc" ] && [ ! -L "$NVIM_DIR/.vimrc" ]; then
	echo "Linking .vimrc into Neovim configuration..."
	ln -s "$HOME/.vimrc" "$NVIM_DIR/.vimrc"
fi

echo "Setup completed."
