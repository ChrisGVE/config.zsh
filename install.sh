#!/usr/bin/env bash

###############################################################################
# Installation Script
#
# Purpose:
# This script handles the initial installation of the zsh configuration system.
# It sets up the directory structure and ensures all scripts are in their proper
# locations. This is a one-time setup script that prepares the environment for
# the dependencies management system.
#
# Directory Structure:
# ~/.config/zsh/                    - Main configuration directory (source)
# ├── install/                      - Installation support scripts
# │   ├── common.sh                 - Common functions
# │   ├── toolchains.sh            - Toolchain management
# │   └── tools/                    - Individual tool installers
# └── dependencies.sh               - Main management script
#
# /opt/local/bin or /usr/local/bin - System-wide tool installation (target)
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
# - System binary directories for tool installation
# - Cache directories for building
setup_base_dirs() {
	# Define all required directories
	local dirs=(
		"/opt/local/bin"         # Preferred system-wide binary location
		"/usr/local/bin"         # Fallback binary location
		"$HOME/.cache/zsh/tools" # Build cache
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
# Script Organization
###############################################################################

# Ensure scripts are properly organized
organize_scripts() {
	local base_dir="$HOME/.config/zsh"

	info "Organizing installation scripts..."

	# Ensure install directory exists
	mkdir -p "$base_dir/install/tools"

	# Move scripts to their proper locations if needed
	if [ -f "dependencies.sh" ] && [ ! -f "$base_dir/dependencies.sh" ]; then
		mv dependencies.sh "$base_dir/"
	fi

	# Ensure proper permissions
	chmod +x "$base_dir/dependencies.sh"
	chmod +x "$base_dir/install/"*.sh
	chmod +x "$base_dir/install/tools/"*.sh

	info "Scripts organized successfully"
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting installation process..."

	# Create system directories
	setup_base_dirs

	# Organize scripts
	organize_scripts

	info "Installation complete. Use 'dependencies' command to install/update tools."
}

# Execute main installation process
main "$@"
