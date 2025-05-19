#! @shell@

set -euo pipefail

flakeUri="@FLAKE_URI_BASE@"

usage() {
	echo "Usage: bootstrap <darwin|linux> [target_name] [--flake <flake_uri>]"
}

POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
	case $1 in
	--flake)
		if [[ -n "$2" && "$2" != --* ]]; then
			flakeUri="$2"
			shift
			shift
		else
			echo "Error: --flake requires a non-empty argument." >&2
			usage
			exit 1
		fi
		;;
	*)
		POSITIONAL_ARGS+=("$1")
		shift
		;;
	esac
done
set -- "${POSITIONAL_ARGS[@]}"

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	usage
	exit 1
fi

SYSTEM_TYPE="$1"
TARGET_NAME="${2:-}"

FLAKE_TARGET=""
extraBuildFlags=(-v --show-trace --no-link)
extraLockFlags=(-L)

case "$SYSTEM_TYPE" in
darwin)
	if [ -z "$TARGET_NAME" ]; then
		FLAKE_TARGET="appl-mbp16"
	else
		FLAKE_TARGET="$TARGET_NAME"
	fi
	;;
linux)
	if [ -z "$TARGET_NAME" ]; then
		FLAKE_TARGET="ubuntu"
	else
		FLAKE_TARGET="$TARGET_NAME"
	fi
	;;
*)
	usage
	exit 1
	;;
esac
echo "building system configuration for $SYSTEM_TYPE..." >&2

flake="${flakeUri}#${FLAKE_TARGET}"
if [[ $flake =~ ^(.*)\#([^\#\"]*)$ ]]; then
	flake="${BASH_REMATCH[1]}"
	flakeAttr="${BASH_REMATCH[2]}"
fi

case "$SYSTEM_TYPE" in
darwin)
	if [[ $(id -u) -eq 0 ]]; then
		# On macOS, `sudo(8)` preserves `$HOME` by default, which causes Nix
		# to output warnings.
		HOME=~root
	fi
	SUDO_USER=aarnphm sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake "$flake#$flakeAttr" --show-trace -v -L --option accept-flake-config true
	;;
linux)
	nix run home-manager/master -- switch --flake "$flake#$flakeAttr" --show-trace -v -L --option accept-flake-config true
	;;
esac

if ! gh auth status &>/dev/null; then
	echo "Logging into GitHub via gh..."
	gh auth login -p ssh
fi

if ! rustup toolchain list | grep -q nightly; then
	echo "Installing Rust nightly toolchain..."
	rustup toolchain install nightly
fi

NVIM_DIR="$HOME/.config/nvim"
if [ ! -d "$NVIM_DIR" ]; then
	gh repo clone aarnphm/editor "$NVIM_DIR"
fi

if [ ! -f "$HOME/.vimrc" ] && [ ! -L "$NVIM_DIR/.vimrc" ]; then
	ln -s "$HOME/.vimrc" "$NVIM_DIR/.vimrc"
fi

echo "Setup completed for $SYSTEM_TYPE"
