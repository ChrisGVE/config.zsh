#!/usr/bin/env bash

###############################################################################
# TV (Television) Installation Script
#
# Purpose:
# Installs or updates television (https://github.com/alexpasmantier/television)
# A terminal media player
#
# Dependencies:
# - Rust toolchain (automatically managed)
# - Make
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="tv"
REPO_URL="https://github.com/alexpasmantier/television"
BINARY="tv"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."
	package_install "make"
}

build_tool() {
	local build_dir="$1"
	local version_type="$2"

	# Ensure build directory exists
	if [ ! -d "$build_dir" ]; then
		error "Build directory does not exist: $build_dir"
		return 1
	fi

	# Enter build directory
	cd "$build_dir" || error "Failed to enter build directory: $build_dir"

	# Reset and clean the repository to handle any local changes
	sudo -u root git reset --hard || warn "Failed to reset git repository"
	sudo -u root git clean -fd || warn "Failed to clean git repository"

	# Configure git trust
	sudo git config --global --add safe.directory "$build_dir"

	# Checkout appropriate version
	if [ "$version_type" = "stable" ]; then
		# Get all tags and find the latest version
		sudo git fetch --tags --force || warn "Failed to fetch tags"

		# Find the latest version tag, exclude the 'latest' tag to avoid confusion
		local latest_version=$(git tag -l | grep -v "latest" | grep -E '^v?[0-9]+(\.[0-9]+)+$' | sort -V | tail -n1)

		if [ -n "$latest_version" ]; then
			info "Building version: $latest_version"
			sudo -u root git checkout "$latest_version" || error "Failed to checkout version $latest_version"
		else
			info "No version tags found, using master branch"
			sudo -u root git checkout master || sudo -u root git checkout main || error "Failed to checkout master branch"
		fi
	else
		info "Building from latest HEAD"
		sudo -u root git checkout master || sudo -u root git checkout main || error "Failed to checkout master/main branch"
	fi

	info "Building $TOOL_NAME..."

	# Configure build flags for Rust with resource constraints
	configure_build_flags

	# Limit parallelism for Raspberry Pi
	if [ "$OS_TYPE" = "raspberrypi" ]; then
		info "Configuring resource constraints for Raspberry Pi..."
		export CARGO_BUILD_JOBS=1
		export RUSTFLAGS="-C codegen-units=1"
	else
		export CARGO_BUILD_JOBS="${MAKE_FLAGS#-j}"
	fi

	# Build using make as recommended
	make release || error "Failed to build"

	info "Installing $TOOL_NAME..."
	sudo install -m755 target/release/tv "$BASE_DIR/bin/" || error "Failed to install"
}

###############################################################################
# Main Installation Process
###############################################################################

# Install dependencies first
install_deps

# Setup repository in cache
REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

# Run installation/update
install_or_update_tool "$TOOL_NAME" "$BINARY" "$VERSION_CMD" "$REPO_DIR" build_tool
