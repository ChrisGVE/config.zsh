#!/usr/bin/env bash

###############################################################################
# Neovim Installation Script
#
# Purpose:
# Installs or updates Neovim (https://neovim.io)
# A hyperextensible Vim-based text editor
#
# Dependencies:
# - Ninja build system
# - CMake
# - Various build dependencies
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="nvim"
REPO_URL="https://github.com/neovim/neovim"
BINARY="nvim"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."
	package_install "ninja-build"
	package_install "gettext"
	package_install "cmake"
	package_install "unzip"
	package_install "curl"
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
		# Try to get latest tag
		local latest_version=$(git tag -l | grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -n1)

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

	# Configure build flags
	configure_build_flags

	# Set CMAKE flags with optimizations
	CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=RelWithDebInfo \
                 -DCMAKE_INSTALL_PREFIX=$BASE_DIR \
                 -DENABLE_LTO=ON"

	# Build
	make clean || true
	make $MAKE_FLAGS CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_FLAGS="$CMAKE_FLAGS" || error "Failed to build"

	info "Installing $TOOL_NAME..."
	sudo make install || error "Failed to install"
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
