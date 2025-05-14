#!/bin/bash

set -euo pipefail

FORCE_INSTALL=false
if [[ "$*" == *"--force-install"* ]]; then
    FORCE_INSTALL=true
fi

# Logging setup from setup_remote.sh.in
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

log_info "Checking for nix"
if ! $FORCE_INSTALL && command -v nix &>/dev/null; then
	log_info "Nix is installed."
	log_info "You can run the latest lambda directly using nix:"
	log_info "  nix run github:${REPO}#lambda"
	exit 0
fi

OS=$(uname -s)
ARCH=$(uname -m)

case $OS in
Linux)
	case $ARCH in
	x86_64)
		SYSTEM="x86_64-linux"
		;;
	aarch64)
		SYSTEM="aarch64-linux"
		;;
	*)
		log_error "Unsupported architecture ($ARCH) for Linux."
		exit 1
		;;
	esac
	;;
Darwin)
	case $ARCH in
	x86_64)
		SYSTEM="x86_64-darwin"
		;;
	arm64) # Darwin uses arm64 for Apple Silicon
		SYSTEM="aarch64-darwin"
		;;
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

RELEASE_ASSET_NAME="lm-${SYSTEM}.zip"

log_info "Detected platform: $SYSTEM"

# Get the latest release tag using GitHub API
log_info "Fetching latest release tag from GitHub..."
LATEST_TAG=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^\"]+)".*/\1/')

if [ -z "$LATEST_TAG" ]; then
	log_error "Could not fetch the latest release tag from GitHub."
	exit 1
fi

log_info "Latest release tag: $LATEST_TAG"

DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/${RELEASE_ASSET_NAME}"
INSTALL_PATH="${INSTALL_DIR}/${BINARY_NAME}"
ZIP_PATH="${TMP_DIR}/${RELEASE_ASSET_NAME}"

log_info "Creating installation directory: ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

log_info "Downloading zip from: ${DOWNLOAD_URL}"
# Use curl's -f flag to fail silently on server errors (like 404 Not Found)
if ! curl -fL "${DOWNLOAD_URL}" -o "${ZIP_PATH}" 2>/dev/null; then
	log_error "Failed to download zip. Check URL or network:"
	log_error "  URL: ${DOWNLOAD_URL}"
	exit 1
fi

log_info "Extracting binary from zip..."
unzip -q -o "${ZIP_PATH}" -d "${TMP_DIR}"

# Find the binary in the extracted content
EXTRACTED_BINARY="${TMP_DIR}/lm-${SYSTEM}/bin/${BINARY_NAME}"
if [ ! -f "$EXTRACTED_BINARY" ]; then
    log_error "Binary not found in extracted zip at expected path: ${EXTRACTED_BINARY}"
    log_error "Zip structure may have changed. Files in the extracted directory:"
    find "${TMP_DIR}" -type f | sort
    exit 1
fi

if [ -f "${INSTALL_PATH}" ] && ! $FORCE_INSTALL; then
    log_warn "Binary '${BINARY_NAME}' already exists at ${INSTALL_PATH}. This installation will override it."
		exit 1
fi

log_info "Installing binary to ${INSTALL_PATH}"
cp "${EXTRACTED_BINARY}" "${INSTALL_PATH}"
chmod +x "${INSTALL_PATH}"

# Check if INSTALL_DIR is in PATH
if [[ ":$PATH:" == *":${INSTALL_DIR}:"* ]]; then
	log_info "✅ ${BINARY_NAME} installed successfully to ${INSTALL_PATH}"
	log_info "You can now run '${BINARY_NAME}' from your terminal."
else
	log_warn "⚠️ ${BINARY_NAME} installed to ${INSTALL_PATH}, but the directory is not in your PATH."
	log_warn "Please add the following line to your shell configuration file (~/.bashrc, ~/.zshrc, etc.):"
	log_warn "  export PATH=\"${INSTALL_DIR}:\$PATH\""
	log_warn "Then, reload your shell for the changes to take effect (e.g., run 'source ~/.zshrc' or restart your terminal)."
fi

exit 0
