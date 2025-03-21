#!/usr/bin/env bash

###############################################################################
# Lazygit Installation Script
#
# Purpose:
# Installs or updates lazygit (https://github.com/jesseduffield/lazygit)
# A simple terminal UI for git commands
#
# Dependencies:
# - Go toolchain (automatically managed)
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="lazygit"
REPO_URL="https://github.com/jesseduffield/lazygit"
BINARY="lazygit"
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
	# Set up Go environment
	export GOPATH="$build_dir/go"
	mkdir -p "$GOPATH"

	# Build
	go build -o lazygit || error "Failed to build"

	info "Installing $TOOL_NAME..."
	sudo install -m755 lazygit "$BASE_DIR/bin/" || error "Failed to install"
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
