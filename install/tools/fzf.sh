#!/usr/bin/env bash

###############################################################################
# FZF Installation Script
#
# Purpose:
# Installs or updates fzf (https://github.com/junegunn/fzf)
# A command-line fuzzy finder
#
# Dependencies:
# - Go toolchain (automatically managed)
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="fzf"
REPO_URL="https://github.com/junegunn/fzf"
BINARY="fzf"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."
	# No additional dependencies beyond Go, which is managed by toolchains.sh
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
# Reset and clean the repository before checkout
(cd "$build_dir" && sudo -u root git reset --hard)
(cd "$build_dir" && sudo -u root git clean -fd)
		sudo -u root git checkout "$latest_version" || error "Failed to checkout version $latest_version"
	else
		info "Building from latest HEAD"
# Reset and clean the repository before checkout
(cd "$build_dir" && sudo -u root git reset --hard)
(cd "$build_dir" && sudo -u root git clean -fd)
		sudo -u root git checkout master || error "Failed to checkout master branch"
	fi

	info "Building $TOOL_NAME..."
	make clean
	make || error "Failed to build"

	info "Installing $TOOL_NAME..."
	# Install the binary
	sudo install -m755 bin/fzf "$BASE_DIR/bin/" || error "Failed to install binary"

	# Install shell completion and key bindings to system location for all users
	sudo mkdir -p "$BASE_DIR/share/fzf"
	sudo cp shell/*.zsh "$BASE_DIR/share/fzf/"
	sudo cp shell/*.bash "$BASE_DIR/share/fzf/"
	sudo cp shell/*.fish "$BASE_DIR/share/fzf/"
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
