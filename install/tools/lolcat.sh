#!/usr/bin/env bash

###############################################################################
# Lolcat Installation Script
#
# Purpose:
# Installs or updates lolcat (https://github.com/busyloop/lolcat)
# A command that displays text with rainbow colors
#
# Dependencies:
# - Ruby and development files
# - Build tools
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="lolcat"
REPO_URL="https://github.com/busyloop/lolcat"
BINARY="lolcat"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."
	package_install "ruby"
	package_install "ruby-dev"
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

	info "Building and installing $TOOL_NAME..."
	# Build gem
	gem build lolcat.gemspec || error "Failed to build gem"

	# Install gem
	sudo gem install --no-user-install lolcat-*.gem || error "Failed to install gem"
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
