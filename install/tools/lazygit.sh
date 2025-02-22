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
TOOL_NAME="lazygit"
REPO_URL="https://github.com/jesseduffield/lazygit"
BINARY="lazygit"
VERSION_CMD="--version"

install_deps() {
	info "Installing lazygit build dependencies..."
	ensure_go_toolchain
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

	info "Building lazygit..."
	go build || error "Failed to build"

	info "Installing lazygit..."
	sudo install -m755 lazygit /usr/local/bin/ || error "Failed to install"
}

# Install dependencies first
install_deps

# Setup repository
REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

# Run installation/update
install_or_update_tool "$TOOL_NAME" "$BINARY" "$VERSION_CMD" "$REPO_DIR" "build_tool"
