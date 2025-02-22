#!/usr/bin/env bash

# Set up environment
set -f # Disable glob expansion
ZSHENV="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zshenv"
export BASH_SOURCE_ZSHENV=$(grep -v '\[\[' "$ZSHENV")
eval "$BASH_SOURCE_ZSHENV"
set +f # Re-enable glob expansion

# Set installation directory
INSTALL_DATA_DIR="${XDG_DATA_HOME}/zsh/install"

# Source common functions
source "${INSTALL_DATA_DIR}/common.sh"

# Tool-specific configuration
TOOL_NAME="yazi"
REPO_URL="https://github.com/sxyazi/yazi"
BINARY="yazi"
VERSION_CMD="--version"

install_deps() {
	info "Installing yazi build dependencies..."
	package_install "cargo"
	package_install "rustc"
	package_install "pkg-config"
	package_install "libglib2.0-dev"
	package_install "ffmpegthumbnailer" # For image previews
	package_install "unar"              # For archive previews
}

build_tool() {
	local build_dir="$1"
	local version_type="$2"

	if [ ! -d "$build_dir" ]; then
		error "Build directory does not exist: $build_dir"
		return 1
	fi

	cd "$build_dir" || error "Failed to enter build directory: $build_dir"

	if [ "$version_type" = "stable" ]; then
		latest_version=$(get_target_version "$build_dir" "stable")
		info "Checking out stable version: $latest_version"
		git checkout "$latest_version" || error "Failed to checkout version $latest_version"
	else
		info "Using development version (HEAD)"
		git checkout master || error "Failed to checkout master branch"
	fi

	info "Building yazi..."
	# Configure build flags for Rust
	configure_build_flags
	export CARGO_BUILD_JOBS="${MAKE_FLAGS#-j}"

	# Build with cargo
	cargo build --release || error "Failed to build"

	info "Installing yazi..."
	sudo install -m755 target/release/yazi /usr/local/bin/ || error "Failed to install"
}

# Install dependencies first
install_deps

# Setup repository
REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

# Run installation/update
install_or_update_tool "$TOOL_NAME" "$BINARY" "$VERSION_CMD" "$REPO_DIR" "build_tool"
