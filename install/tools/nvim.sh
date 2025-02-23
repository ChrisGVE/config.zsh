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
TOOL_NAME="nvim"
REPO_URL="https://github.com/neovim/neovim"
BINARY="nvim"
VERSION_CMD="--version"

install_binary() {
	sudo install -m755 binary "${INSTALL_BASE_DIR}/bin/" || error "Failed to install binary"
}

install_deps() {
	info "Installing Neovim build dependencies..."
	package_install "ninja-build"
	package_install "gettext"
	package_install "cmake"
	package_install "unzip"
	package_install "curl"
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

	info "Building Neovim..."
	configure_build_flags

	# Set CMAKE flags for Raspberry Pi
	CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=RelWithDebInfo \
                 -DCMAKE_INSTALL_PREFIX=/usr/local \
                 -DENABLE_LTO=ON \
                 -DCMAKE_C_FLAGS=-march=native"

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
