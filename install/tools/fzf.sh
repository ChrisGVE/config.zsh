#!/usr/bin/env bash

# Source common functions which will setup the environment
source "${XDG_DATA_HOME:-$HOME/.local/share}/zsh/install/common.sh"

# Tool-specific configuration
TOOL_NAME="fzf"
REPO_URL="https://github.com/junegunn/fzf"
BINARY="fzf"
VERSION_CMD="--version"

install_deps() {
	info "Installing FZF build dependencies..."
	sudo apt-get update || error "Failed to update apt"
	sudo apt-get install -y golang-go || error "Failed to install dependencies"
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

	info "Building FZF..."
	make clean
	make || error "Failed to build"

	info "Installing FZF..."
	sudo mv bin/fzf /usr/local/bin/ || error "Failed to install"
}

# Install dependencies first
install_deps

# Setup repository
REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

# Run installation/update
install_or_update_tool "$TOOL_NAME" "$BINARY" "$VERSION_CMD" "$REPO_DIR" "build_tool"
