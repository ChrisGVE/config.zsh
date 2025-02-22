#!/usr/bin/env bash

###############################################################################
# Installation Bootstrap Script
#
# Purpose:
# Provides the main entry point for system setup, including:
# - Initial system checks
# - Directory structure setup
# - Sudo access verification
# - Dependencies installation
###############################################################################

set -euo pipefail

# Print status messages
info() { echo "[INFO] $1" >&2; }
warn() { echo "[WARN] $1" >&2; }
error() {
	echo "[ERROR] $1"
	exit 1
}

# Check for basic requirements
check_requirements() {
	# Check for bash version >= 4
	if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
		error "Bash version 4 or higher is required"
	fi

	# Check for required commands
	local required_commands=("curl" "git")
	for cmd in "${required_commands[@]}"; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			error "Required command not found: $cmd"
		fi
	done
}

# Setup installation directories
setup_directories() {
	local dirs=(
		"/opt/local/bin"
		"/usr/local/bin"
	)

	for dir in "${dirs[@]}"; do
		if [ ! -d "$dir" ]; then
			if sudo -n mkdir -p "$dir" 2>/dev/null; then
				sudo -n chmod 775 "$dir"
				info "Created directory: $dir"
			else
				warn "Could not create directory: $dir"
			fi
		fi
	done
}

# Main installation process
main() {
	local SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

	info "Starting installation..."

	# 1. Check basic requirements
	check_requirements

	# 2. Setup necessary directories
	setup_directories

	# 3. Run dependencies installation
	info "Running dependencies installation..."
	bash "${SCRIPT_DIR}/dependencies.sh" || error "Dependencies installation failed"

	info "Installation completed successfully"
}

# Execute main function
main "$@"
