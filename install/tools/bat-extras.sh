#!/usr/bin/env bash

###############################################################################
# Bat-Extras Installation Script
#
# Purpose:
# Installs or updates bat-extras (https://github.com/eth-p/bat-extras)
# A collection of scripts that integrate with bat
#
# Dependencies:
# - bat (must be installed first)
# - shfmt (for script modifications)
#
# Installed Scripts:
# - batdiff (better git diff)
# - batgrep (better grep)
# - batman (better man)
# - batpipe (better pager)
# - batwatch (better watch)
# and more...
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="bat-extras"
REPO_URL="https://github.com/eth-p/bat-extras"
BINARY="batdiff" # Use one of the scripts for version checking
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME dependencies..."

	# Check if bat is installed
	if ! command -v bat >/dev/null 2>&1; then
		error "bat must be installed first"
	fi

	# Install shfmt for script modifications
	package_install "shfmt"
}

build_tool() {
	local build_dir="$1"
	local version_type="$2"

	if [ ! -d "$build_dir" ]; then
		error "Build directory does not exist: $build_dir"
		return 1
	fi

	cd "$build_dir" || error "Failed to enter build directory: $build_dir"

	# Checkout appropriate version
	if [ "$version_type" = "stable" ]; then
		local latest_version=$(get_target_version "$build_dir" "stable")
		info "Building version: $latest_version"
		sudo -u root git checkout "$latest_version" || error "Failed to checkout version $latest_version"
	else
		info "Building from latest HEAD"
		sudo -u root git checkout master || error "Failed to checkout master branch"
	fi

	info "Building $TOOL_NAME..."

	# Build and install to system directory
	sudo ./build.sh --prefix="$BASE_DIR" --install || error "Failed to build and install"
}

###############################################################################
# Main Installation Process
###############################################################################

# Install dependencies first
install_deps

# Setup repository in cache
REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

# Run installation/update
install_or_update_tool "$TOOL_NAME" "$BINARY" "$VERSION_CMD" "$REPO_DIR" "build_tool"
