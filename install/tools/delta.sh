#!/usr/bin/env bash

###############################################################################
# Delta Installation Script
#
# Purpose:
# Installs or updates delta (https://github.com/dandavison/delta)
# A syntax-highlighting pager for git, diff, and grep output
#
# Dependencies:
# - Rust toolchain (automatically managed)
# - Basic build tools (cmake, pkg-config)
#
# Post-Installation:
# Configures git to use delta:
# - core.pager = delta
# - interactive.diffFilter = delta --color-only
# - delta.navigate = true
# - merge.conflictStyle = zdiff3
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="delta"
REPO_URL="https://github.com/dandavison/delta"
BINARY="delta"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."
	# Basic build dependencies
	package_install "cmake"
	package_install "pkg-config"
	package_install "libssl-dev"
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
		git checkout "$latest_version" || error "Failed to checkout version $latest_version"
	else
		info "Building from latest HEAD"
		git checkout master || error "Failed to checkout master branch"
	fi

	info "Building $TOOL_NAME..."
	# Configure build flags for Rust
	configure_build_flags
	export CARGO_BUILD_JOBS="${MAKE_FLAGS#-j}"

	# Build with cargo
	cargo build --release || error "Failed to build"

	info "Installing $TOOL_NAME..."
	sudo install -m755 target/release/delta "$BASE_DIR/bin/" || error "Failed to install"
}

###############################################################################
# Post-Installation Configuration
###############################################################################

configure_git() {
	info "Configuring git to use delta..."

	# Configure git globally
	git config --global core.pager delta
	git config --global interactive.diffFilter "delta --color-only"
	git config --global delta.navigate true
	git config --global merge.conflictStyle zdiff3

	info "Git configuration complete"
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

# Configure git (this will be handled by the post command in tools.conf)
# configure_git
