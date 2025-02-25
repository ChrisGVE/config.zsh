#!/usr/bin/env bash

###############################################################################
# Main Dependencies Installation Script
#
# Purpose:
# This script manages the installation and updating of development tools and
# their dependencies in a multi-user environment. It serves as the main entry
# point for:
# 1. System package manager updates
# 2. Development toolchain installation and updates
# 3. Individual tool installations
#
# The script ensures:
# - Consistent installation across different systems
# - Proper toolchain management
# - Individual tool installations with version control
###############################################################################

set -euo pipefail

# Print status messages
info() { echo "[INFO] $1" >&2; }
warn() { echo "[WARN] $1" >&2; }
error() {
	echo "[ERROR] $1"
	exit 1
}

###############################################################################
# Environment Detection and Setup
###############################################################################

# Detect and store the system's package manager
detect_package_manager() {
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		case "$ID" in
		debian | ubuntu | raspbian)
			export PACKAGE_MANAGER="apt"
			;;
		fedora | rhel | centos)
			export PACKAGE_MANAGER="dnf"
			;;
		arch | manjaro)
			export PACKAGE_MANAGER="pacman"
			;;
		*)
			# Fallback to checking available package managers
			if command -v apt >/dev/null 2>&1; then
				export PACKAGE_MANAGER="apt"
			elif command -v dnf >/dev/null 2>&1; then
				export PACKAGE_MANAGER="dnf"
			elif command -v pacman >/dev/null 2>&1; then
				export PACKAGE_MANAGER="pacman"
			else
				error "Unsupported distribution: $ID"
			fi
			;;
		esac
	else
		error "Cannot determine distribution type"
	fi
}

# Update system package manager if we have non-interactive sudo access
update_package_manager() {
	info "Checking package manager update access..."

	# Test for non-interactive sudo access
	if ! sudo -n true 2>/dev/null; then
		warn "No non-interactive sudo access. Skipping package manager update."
		return 0
	fi

	info "Updating package manager..."
	case "$PACKAGE_MANAGER" in
	apt)
		sudo -n apt update
		;;
	dnf)
		sudo -n dnf check-update || true # dnf returns 100 if updates available
		;;
	pacman)
		sudo -n pacman -Sy
		;;
	esac
}

###############################################################################
# Installation Directory Management
###############################################################################

# Get the appropriate user-level installation directory
# Prefers /opt/local/bin if it exists, falls back to /usr/local/bin
# Creates the chosen directory structure if neither exists
get_install_dir() {
	# First check existing bin directories
	if [ -d "/opt/local/bin" ]; then
		echo "/opt/local"
	elif [ -d "/usr/local/bin" ]; then
		echo "/usr/local"
	else
		# If neither exists, prefer /opt/local and ensure bin exists
		local base_dir="/opt/local"
		if sudo -n mkdir -p "${base_dir}/bin" 2>/dev/null; then
			sudo -n chmod 775 "${base_dir}/bin"
			echo "$base_dir"
		else
			# Fallback to /usr/local if /opt/local creation fails
			base_dir="/usr/local"
			if sudo -n mkdir -p "${base_dir}/bin" 2>/dev/null; then
				sudo -n chmod 775 "${base_dir}/bin"
				echo "$base_dir"
			else
				error "Could not create either /opt/local/bin or /usr/local/bin"
			fi
		fi
	fi
}

###############################################################################
# Git Repository Trust and Permissions
###############################################################################

# Verify and fix repository trust and permission issues
verify_git_repos() {
	info "Verifying git repository trust and permissions..."

	# First, make sure the cache directory exists with proper permissions
	local cache_dir="$INSTALL_DIR/share/dev/cache"
	sudo mkdir -p "$cache_dir"
	sudo chown root:staff "$cache_dir"
	sudo chmod 775 "$cache_dir"

	# Then fix each repository
	for repo_dir in $(find "$cache_dir" -type d -name ".git" -exec dirname {} \; 2>/dev/null || echo ""); do
		info "Ensuring Git trust for repository: $repo_dir"
		sudo git config --global --add safe.directory "$repo_dir"

		# Fix permissions on this repository
		info "Fixing permissions for repository: $repo_dir"
		sudo chown -R root:staff "$repo_dir"
		sudo chmod -R 775 "$repo_dir"

		# Remove any lock files
		if [ -f "$repo_dir/.git/index.lock" ]; then
			sudo rm -f "$repo_dir/.git/index.lock"
		fi
	done
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	local SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
	local INSTALL_DIR="$(get_install_dir)"

	# 1. Detect package manager
	detect_package_manager

	# 2. Update system package manager if possible
	update_package_manager

	# 3. Ensure development toolchains are installed and up to date
	info "Setting up development toolchains..."
	bash "${SCRIPT_DIR}/toolchains.sh" "$INSTALL_DIR" || error "Toolchain setup failed"

	# 4. Source common functions for tool installation
	export INSTALL_BASE_DIR="$INSTALL_DIR" # Export for all child scripts
	source "${SCRIPT_DIR}/common.sh" || error "Failed to source common functions"

	# 5. Verify and fix git repository trust and permissions
	verify_git_repos

	# 6. Process each tool installation script
	local TOOLS_DIR="${SCRIPT_DIR}/tools"
	if [ ! -d "$TOOLS_DIR" ]; then
		error "Tools directory not found: $TOOLS_DIR"
	fi

	info "Running dependencies management..."
	for tool in "${TOOLS_DIR}"/*.sh; do
		if [ -f "$tool" ]; then
			info "Processing: $(basename "$tool")"
			bash "$tool" || warn "Failed to process $(basename "$tool"), continuing..."
		fi
	done

	info "All tools processed successfully"
	info "The user specific install can now be setup by running 'user-post-install.sh'"
}

# Execute main function
main "$@"
