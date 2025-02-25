#!/usr/bin/env bash

###############################################################################
# Figlet Installation Script
#
# Purpose:
# Installs or updates figlet (http://www.figlet.org/)
# A program for making large letters out of ordinary text
#
# Dependencies:
# - Basic build tools (gcc, make)
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="figlet"
REPO_URL="https://github.com/cmatsuoka/figlet"
BINARY="figlet"
VERSION_CMD="-v"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."
	package_install "build-essential"
}

build_tool() {
	local build_dir="$1"
	local version_type="$2"

	if [ ! -d "$build_dir" ]; then
		error "Build directory does not exist: $build_dir"
		return 1
	fi

	cd "$build_dir" || error "Failed to enter build directory: $build_dir"

	# Figlet doesn't use version tags, use latest commit on master
	info "Using latest version from master branch"
# Reset and clean the repository before checkout
(cd "$build_dir" && sudo -u root git reset --hard)
(cd "$build_dir" && sudo -u root git clean -fd)
# Reset and clean the repository before checkout
(cd "$build_dir" && sudo -u root git reset --hard)
(cd "$build_dir" && sudo -u root git clean -fd)
	sudo -u root git checkout master || error "Failed to checkout master branch"

	info "Building $TOOL_NAME..."
	# Configure build flags
	configure_build_flags

	# Build
	make $MAKE_FLAGS all || error "Failed to build"

	info "Installing $TOOL_NAME..."
	sudo make install prefix="$BASE_DIR" || error "Failed to install"
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
