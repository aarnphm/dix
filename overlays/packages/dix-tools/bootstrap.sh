#! @shell@

set -euo pipefail

flakeUri="@FLAKE_URI_BASE@"

usage() {
	echo "usage: bootstrap <darwin|linux> [target_name] [--flake <flake_uri>]"
}

ERROR_COLOR="\033[0;31m" # Red
LOG_COLOR="\033[0;32m"   # Green
WARN_COLOR="\033[0;34m"  # Blue
DEBUG_COLOR="\033[0;35m" # Purple
RESET_COLOR="\033[0m"

log() {
	local level=$1
	local caller=$2
	local message=$3

	# Convert caller to uppercase
	caller=$(echo "$caller" | tr '[:lower:]' '[:upper:]')

	# Set color based on log level
	local color=""
	case $level in
	"ERROR")
		color=$ERROR_COLOR
		;;
	"INFO")
		color=$LOG_COLOR
		;;
	"WARN" | "WARNING")
		color=$WARN_COLOR
		;;
	"DEBUG")
		color=$DEBUG_COLOR
		;;
	*)
		color=$RESET_COLOR
		;;
	esac

	# Print formatted log message
	echo -e "${color}[${caller}]${RESET_COLOR} ${message}"
}

log_info() {
	local message=$1
	log "INFO" "DETACH" "$message"
}

log_warn() {
	local message=$1
	log "WARN" "DETACH" "$message"
}

log_error() {
	local message=$1
	log "ERROR" "DETACH" "$message"
}

log_debug() {
	local message=$1
	log "DEBUG" "DETACH" "$message"
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
			log_error "--flake requires a non-empty argument."
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

TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
log_info "setup @ $SYSTEM_TYPE at $TIMESTAMP"

flake="${flakeUri}#${FLAKE_TARGET}"
if [[ $flake =~ ^(.*)\#([^\#\"]*)$ ]]; then
	flake="${BASH_REMATCH[1]}"
	flakeAttr="${BASH_REMATCH[2]}"
fi

case "$SYSTEM_TYPE" in
darwin)
	SUDO_USER=aarnphm sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake "$flake#$flakeAttr" --show-trace -v -L --option accept-flake-config true
	;;
linux)
	nix run home-manager/master -- switch --flake "$flake#$flakeAttr" --show-trace -v -L --option accept-flake-config true
	;;
esac

if ! gh auth status &>/dev/null; then
	log_info "setup with gh"
	gh auth login -p ssh
fi

if ! rustup toolchain list | grep -q nightly; then
	log_info "install rust toolchain nightly"
	rustup toolchain install nightly
fi

NVIM_DIR="$HOME/.config/nvim"
if [ ! -d "$NVIM_DIR" ]; then
	log_info "default nvim setup"
	gh repo clone aarnphm/editor "$NVIM_DIR"
	nvim --headless "+Lazy! sync" +qa
	nvim --headless -c 'lua require("nvim-treesitter.install").update({ with_sync = true }); vim.cmd("quitall")'
fi

if [ ! -f "$HOME/.vimrc" ] && [ ! -L "$NVIM_DIR/.vimrc" ]; then
	log_info "link .vimrc config"
	ln -s "$HOME/.vimrc" "$NVIM_DIR/.vimrc"
fi

log_info "finished @ $SYSTEM_TYPE"
