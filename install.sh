#!/usr/bin/env bash

###############################################################################
# Installation Script
#
# Purpose:
# This script handles the initial installation of the zsh configuration system.
# It sets up the directory structure and copies all scripts to their proper
# locations. This is a one-time setup script that should be run before using
# the dependencies management system.
#
# Directory Structure Created:
# /opt/local/bin or /usr/local/bin - System-wide tool installation
# ~/.config/zsh/                    - Main configuration directory
# ├── install/                      - Installation support scripts
# │   ├── common.sh                 - Common functions
# │   ├── toolchains.sh            - Toolchain management
# │   └── tools/                    - Individual tool installers
# └── dependencies.sh              - Main management script
#
# After installation, users should use the 'dependencies' command to
# manage tool installations and updates.
###############################################################################

set -euo pipefail

# Status message functions
# Print informational messages to stderr to keep stdout clean
info() { echo "[INFO] $1" >&2; }
error() {
	echo "[ERROR] $1"
	exit 1
}

###############################################################################
# Directory Management
###############################################################################

# Create all necessary directories for the system
# This includes:
# - System binary directories
# - Configuration directories
# - Cache directories
setup_base_dirs() {
	# Define all required directories
	local dirs=(
		"/opt/local/bin"                  # Preferred system-wide binary location
		"/usr/local/bin"                  # Fallback binary location
		"$HOME/.config/zsh/install/tools" # Tool installation scripts
		"$HOME/.cache/zsh/tools"          # Build cache
	)

	info "Creating directory structure..."
	for dir in "${dirs[@]}"; do
		if [ ! -d "$dir" ]; then
			if ! mkdir -p "$dir"; then
				error "Failed to create directory: $dir"
			fi
			info "Created directory: $dir"
		fi
	done
}

###############################################################################
# Script Installation
###############################################################################

# Install all scripts to their proper locations
# Copies scripts from the source directory to their runtime locations
# and sets appropriate permissions
install_scripts() {
	local script_dir="$(dirname "$(readlink -f "$0")")"
	local config_dir="$HOME/.config/zsh"

	info "Installing configuration scripts..."

	# Check if we're already in the target directory
	if [[ "$script_dir" == "$config_dir" ]]; then
		error "Cannot install from target directory. Please run install.sh from the source directory."
	fi

	# Create install directory if it doesn't exist
	mkdir -p "$config_dir/install/tools"

	# Copy main management script
	cp "$script_dir/dependencies.sh" "$config_dir/" || error "Failed to copy dependencies.sh"

	# Copy installation support scripts
	cp "$script_dir/install/"*.sh "$config_dir/install/" || error "Failed to copy support scripts"

	# Copy individual tool installers
	cp "$script_dir/install/tools/"*.sh "$config_dir/install/tools/" ||
		error "Failed to copy tool scripts"

	# Set executable permissions
	chmod +x "$config_dir/dependencies.sh"
	chmod +x "$config_dir/install/"*.sh
	chmod +x "$config_dir/install/tools/"*.sh

	info "Scripts installed successfully"
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting installation process..."

	# Create directory structure
	setup_base_dirs

	# Install all scripts
	install_scripts

	info "Installation complete. Use 'dependencies' command to install/update tools."
}

# Execute main installation process
main "$@"
