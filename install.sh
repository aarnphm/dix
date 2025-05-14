#!/bin/bash

set -euo pipefail

FORCE_INSTALL=false

ERROR_COLOR="\033[0;31m"
LOG_COLOR="\033[0;32m"
WARN_COLOR="\033[0;34m"
DEBUG_COLOR="\033[0;35m"
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

	# Print formatted log message to stderr to avoid interfering with potential script output piping
	echo -e "${color}[${caller}]${RESET_COLOR} ${message}" >&2
}

# Define specific log functions for the installer
log_info() {
	local message=$1
	log "INFO" "DIX" "$message"
}

log_warn() {
	local message=$1
	log "WARN" "DIX" "$message"
}

log_error() {
	local message=$1
	log "ERROR" "DIX" "$message"
}

log_debug() {
	local message=$1
	log "DEBUG" "DIX" "$message"
}

REPO="aarnphm/dix"
BINARY_NAME="lm"
INSTALL_DIR="$HOME/.local/bin"
TMP_DIR=$(mktemp -d)

cleanup() {
	if [[ -d "$TMP_DIR" ]]; then
		rm -rf "$TMP_DIR"
	fi
}

# Set up trap to ensure cleanup on exit
trap cleanup EXIT

usage() {
	echo "Usage: $0 [-h|--help] [--force-install]"
	echo
	echo "Installs the '${BINARY_NAME}' binary from GitHub releases."
	echo "If Nix is detected on the system, it will suggest using Nix to run the tool"
	echo "unless --force-install is specified."
	echo
	echo "Options:"
	echo "  -h, --help        Show this help message and exit."
	echo "  --force-install   Bypass Nix check and install the binary directly from GitHub."
	echo "                    If the binary already exists at ${INSTALL_DIR}/${BINARY_NAME},"
	echo "                    it will be overwritten. Otherwise, the script will warn and exit if not forcing."
}

main() {
	if $FORCE_INSTALL; then
		log_info "--force-install specified. Proceeding with binary installation from GitHub."
	fi

	# Determine OS and architecture
	OS=$(uname -s)
	ARCH=$(uname -m)
	local SYSTEM=""

	case $OS in
	Linux)
		case $ARCH in
		x86_64) SYSTEM="x86_64-linux" ;;
		aarch64) SYSTEM="aarch64-linux" ;;
		*)
			log_error "Unsupported architecture ($ARCH) for Linux."
			exit 1
			;;
		esac
		;;
	Darwin)
		case $ARCH in
		x86_64) SYSTEM="x86_64-darwin" ;;
		arm64) SYSTEM="aarch64-darwin" ;; # Darwin uses arm64 for Apple Silicon
		*)
			log_error "Unsupported architecture ($ARCH) for Darwin/macOS."
			exit 1
			;;
		esac
		;;
	*)
		log_error "Unsupported operating system ($OS)."
		exit 1
		;;
	esac

	local RELEASE_ASSET_NAME="${BINARY_NAME}-${SYSTEM}.zip"

	log_info "Detected platform: $SYSTEM"

	log_info "Fetching latest release tag from GitHub..."
	LATEST_TAG=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

	if [ -z "$LATEST_TAG" ]; then
		log_error "Could not fetch the latest release tag from GitHub."
		exit 1
	fi
	log_info "Latest release tag: $LATEST_TAG"

	local INSTALL_PATH="${INSTALL_DIR}/${BINARY_NAME}"
	local ZIP_PATH="${TMP_DIR}/${RELEASE_ASSET_NAME}"
	local DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/${RELEASE_ASSET_NAME}"

	log_info "Creating installation directory: ${INSTALL_DIR}"
	mkdir -p "${INSTALL_DIR}"

	if [ -f "${INSTALL_PATH}" ]; then
		if $FORCE_INSTALL; then
			log_warn "Binary '${BINARY_NAME}' already exists at ${INSTALL_PATH}. Overwriting due to --force-install."
			rm -f "${INSTALL_PATH}"
		else
			log_warn "Binary '${BINARY_NAME}' already exists at ${INSTALL_PATH}. Use --force-install to override it, or remove it manually."
			exit 1
		fi
	fi

	log_info "Downloading zip from: ${DOWNLOAD_URL}"
	if ! curl -fL "${DOWNLOAD_URL}" -o "${ZIP_PATH}" 2>/dev/null; then
		log_error "Failed to download zip. Check URL or network:"
		log_error "  URL: ${DOWNLOAD_URL}"
		exit 1
	fi

	log_info "Extracting binary from zip..."
	unzip -q -o "${ZIP_PATH}" -d "${TMP_DIR}"

	local EXTRACTED_BINARY="${TMP_DIR}/${BINARY_NAME}-${SYSTEM}/bin/${BINARY_NAME}"

	if [ ! -f "$EXTRACTED_BINARY" ]; then
		log_error "Binary '${BINARY_NAME}' not found in extracted zip at expected path:"
		log_error "Zip content in ${TMP_DIR} (look for '${BINARY_NAME}'):"
		find "${TMP_DIR}" -type f -o -type l | sort
		exit 1
	fi
	log_info "Found binary at: ${EXTRACTED_BINARY}"

	log_info "Installing binary to ${INSTALL_PATH}"
	cp "${EXTRACTED_BINARY}" "${INSTALL_PATH}"
	chmod +x "${INSTALL_PATH}"

	# Note: xattr com.apple.quarantine removal was removed in a previous user edit, so not included here.

	if [[ ":$PATH:" == *":${INSTALL_DIR}:"* ]]; then
		log_info "✅ ${BINARY_NAME} installed successfully to ${INSTALL_PATH}"
		log_info "You can now run '${BINARY_NAME}' from your terminal."
	else
		log_warn "⚠️ ${BINARY_NAME} installed to ${INSTALL_PATH}, but the directory is not in your PATH."
		log_warn "Please add the following line to your shell configuration file (~/.bashrc, ~/.zshrc, etc.):"
		log_warn "  export PATH=\"${INSTALL_DIR}:\$PATH\""
		log_warn "Then, reload your shell for the changes to take effect (e.g., run 'source ~/.zshrc' or restart your terminal)."
	fi
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	--force-install)
		FORCE_INSTALL=true
		shift # past argument
		;;
	*)
		log_error "Unknown option: $1"
		usage
		exit 1
		;;
	esac
done

if ! $FORCE_INSTALL && command -v nix &>/dev/null; then
	log_info "Nix is installed on your system."
	log_info "You can run the latest '${BINARY_NAME}' tool directly using Nix:"
	log_info "  nix run github:${REPO}#lambda"
	log_info "To bypass this and install the binary directly from GitHub, use the --force-install flag with this script."
	exit 0
else
	main
fi

exit 0
