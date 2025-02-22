#!/usr/bin/env bash
set -euo pipefail

# Define paths before anything else
TOOLS_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/tools"
INSTALL_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/install"
SCRIPT_PATH="${XDG_BIN_HOME:-$HOME/.local/bin}/dependencies"

# Print status messages
info() { echo "[INFO] $1"; }
warn() { echo "[WARN] $1"; }
error() {
	echo "[ERROR] $1"
	exit 1
}

# Check if a command exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Detect OS
detect_os() {
	case "$(uname -s)" in
	Darwin*)
		export OS_TYPE="macos"
		;;
	Linux*)
		export OS_TYPE="linux"
		if [[ -f /sys/firmware/devicetree/base/model ]]; then
			if grep -q "Raspberry Pi" /sys/firmware/devicetree/base/model; then
				export OS_TYPE="raspberrypi"
			fi
		fi
		;;
	*)
		export OS_TYPE="unknown"
		;;
	esac
}

# Install the dependencies script and its supporting files
install_dependencies_script() {
	info "Installing dependencies script..."

	# Create necessary directories
	mkdir -p "$(dirname "$SCRIPT_PATH")"
	mkdir -p "$INSTALL_DATA_DIR/tools"
	mkdir -p "$TOOLS_CACHE_DIR"

	# Install the main script
	cp "$CURRENT_SCRIPT" "$SCRIPT_PATH"
	chmod +x "$SCRIPT_PATH"

	# Copy supporting files
	REPO_ROOT="$(dirname "$CURRENT_SCRIPT")"
	if [ -d "${REPO_ROOT}/install" ]; then
		cp -r "${REPO_ROOT}/install/common.sh" "$INSTALL_DATA_DIR/"
		cp -r "${REPO_ROOT}/install/tools/"* "$INSTALL_DATA_DIR/tools/"
		chmod +x "$INSTALL_DATA_DIR/tools/"*.sh
	else
		error "Could not find install directory in repository"
	fi

	info "Dependencies script installed. Run 'dependencies' to manage tools."
	exit 0
}

# Source zshenv safely in bash
source_zshenv() {
	set -f # Disable glob expansion
	local ZSHENV="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zshenv"
	# Filter out zsh-specific syntax
	export BASH_SOURCE_ZSHENV=$(grep -v '\[\[' "$ZSHENV")
	eval "$BASH_SOURCE_ZSHENV"
	set +f # Re-enable glob expansion
}

# Main function
main() {
	# First make sure we have the OS type
	detect_os

	# Source zshenv to get XDG paths
	source_zshenv

	INSTALL_DATA_DIR="${XDG_DATA_HOME}/zsh/install"

	# During installation
	mkdir -p "$INSTALL_DATA_DIR"
	cp "install/tools.conf" "$INSTALL_DATA_DIR/"
	cp -r "install/common.sh" "$INSTALL_DATA_DIR/"
	cp -r "install/tools/"* "$INSTALL_DATA_DIR/tools/"

	# Check if we're running from the installed location
	CURRENT_SCRIPT="$(readlink -f "$0")"
	if [ "$CURRENT_SCRIPT" != "$SCRIPT_PATH" ]; then
		install_dependencies_script
	fi

	# If we're here, we're running from the installed location
	info "Running dependencies management..."

	# Source common functions
	source "${INSTALL_DATA_DIR}/common.sh"

	# Run each tool installer
	for tool in "${INSTALL_DATA_DIR}/tools/"*.sh; do
		if [ -f "$tool" ]; then
			info "Processing: $(basename "$tool")"
			bash "$tool"
		fi
	done

	info "All tools processed."
}

main "$@"
