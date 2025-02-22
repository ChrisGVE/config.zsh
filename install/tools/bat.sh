#!/usr/bin/env bash

# Source common functions
source "${INSTALL_DATA_DIR}/common.sh"

# Tool-specific configuration
TOOL_NAME="bat"
REPO_URL="https://github.com/sharkdp/bat"
BINARY="bat"
VERSION_CMD="--version"

install_deps() {
	info "Installing bat build dependencies..."
	sudo apt-get update || error "Failed to update apt"
	sudo apt-get install -y cargo rustc cmake pkg-config libssl-dev || error "Failed to install dependencies"
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

	info "Building bat..."
	# Configure build flags for Rust
	configure_build_flags
	export CARGO_BUILD_JOBS="${MAKE_FLAGS#-j}"

	# Build with cargo
	cargo build --release || error "Failed to build"

	info "Installing bat..."
	sudo install -m755 target/release/bat /usr/local/bin/ || error "Failed to install"

	# Create bat -> batcat symlink if needed
	if ! command_exists batcat; then
		sudo ln -sf /usr/local/bin/bat /usr/local/bin/batcat || warn "Failed to create batcat symlink"
	fi
}

# Install dependencies first
install_deps

# Setup repository
REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

# Run installation/update
install_or_update_tool "$TOOL_NAME" "$BINARY" "$VERSION_CMD" "$REPO_DIR" "build_tool"
