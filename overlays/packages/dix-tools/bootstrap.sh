#! @shell@

set -euo pipefail

export PATH=@path@
export NIX_PATH=${NIX_PATH:-@nixPath@}
profile=@profile@

usage() {
	echo "Usage: bootstrap <darwin|linux> [target_name]"
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
	usage
	exit 1
fi

SYSTEM_TYPE="$1"
TARGET_NAME="${2:-}"

FLAKE_TARGET=""
extraBuildFlags=(-v --show-trace --no-link)
extraLockFlags=(-L)

echo "building the system configuration..." >&2
case "$SYSTEM_TYPE" in
darwin)
	if [[ $(id -u) -eq 0 ]]; then
		# On macOS, `sudo(8)` preserves `$HOME` by default, which causes Nix
		# to output warnings.
		HOME=~root
	fi
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

flake="@FLAKE_URI_BASE@#${FLAKE_TARGET}"
if [[ $flake =~ ^(.*)\#([^\#\"]*)$ ]]; then
	flake="${BASH_REMATCH[1]}"
	flakeAttr="${BASH_REMATCH[2]}"
fi
flakeAttr=darwinConfigurations.${flakeAttr}

systemConfig=$(nix --extra-experimental-features 'nix-command flakes' build --json "${extraBuildFlags[@]}" "${extraLockFlags[@]}" -- "$flake#$flakeAttr.system" | jq -r '.[0].outputs.out')
[[ -x $systemConfig/activate-user ]] && echo "$systemConfig/activate-user"
flake="@FLAKE_URI_BASE@#${FLAKE_TARGET}"
if [ -z "$systemConfig" ]; then exit 0; fi
nix-env -p "$profile" --set "$systemConfig"
"$systemConfig/activate"

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
	echo "Cloning Neovim configuration..."
	gh repo clone aarnphm/editor "$NVIM_DIR"
fi

if [ -f "$HOME/.vimrc" ] && [ ! -L "$NVIM_DIR/.vimrc" ]; then
	echo "Linking .vimrc into Neovim configuration..."
	ln -s "$HOME/.vimrc" "$NVIM_DIR/.vimrc"
fi

echo "Setup completed."
