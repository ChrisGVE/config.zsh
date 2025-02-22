#!/usr/bin/env bash

# Source common functions which will setup the environment
source "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/install/common.sh"

# Tool-specific configuration
TOOL_NAME="neovim"
REPO_URL="https://github.com/neovim/neovim"
BINARY="nvim"
VERSION_CMD="--version"

install_deps() {
	info "Installing Neovim build dependencies..."
	sudo apt-get update || error "Failed to update apt"
	sudo apt-get install -y ninja-build gettext cmake unzip curl || error "Failed to install dependencies"
}

build_tool() {
	local build_dir="$1"
	local version_type="$2"

	cd "$build_dir" || error "Failed to enter build directory"

	if [ "$version_type" = "stable" ]; then
		latest_version=$(get_target_version "$build_dir" "stable")
		info "Checking out stable version: $latest_version"
		git checkout "$latest_version" || error "Failed to checkout version $latest_version"
	else
		info "Using development version (HEAD)"
		git checkout master || error "Failed to checkout master branch"
	fi

	# Configure build flags
	configure_build_flags

	# Set CMAKE flags for Raspberry Pi
	CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=RelWithDebInfo \
                 -DCMAKE_INSTALL_PREFIX=/usr/local \
                 -DENABLE_LTO=ON \
                 -DCMAKE_C_FLAGS=-march=native"

	info "Building Neovim..."
	make clean
	make $MAKE_FLAGS CMAKE_FLAGS="$CMAKE_FLAGS" || error "Failed to build"

	info "Installing Neovim..."
	sudo make install || error "Failed to install"
}

# Install dependencies first
install_deps

# Setup repository
REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

# Run installation/update
install_or_update_tool "$TOOL_NAME" "$BINARY" "$VERSION_CMD" "$REPO_DIR" "build_tool"
