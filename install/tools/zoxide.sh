#!/usr/bin/env bash

###############################################################################
# Zoxide Installation Script
#
# Purpose:
# Installs or updates zoxide (https://github.com/ajeetdsouza/zoxide)
# A smarter cd command inspired by z and autojump
#
# Dependencies:
# - Rust toolchain (automatically managed)
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="zoxide"
REPO_URL="https://github.com/ajeetdsouza/zoxide"
BINARY="zoxide"
VERSION_CMD="-V"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."
	# No additional dependencies beyond Rust
}

install_via_package_manager() {
	info "Installing $TOOL_NAME via package manager..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install zoxide
		;;
	apt)
		# We need a recent version, which might not be in the repos
		# Try to add the official apt repository first
		if ! command -v curl >/dev/null 2>&1; then
			sudo apt-get update
			sudo apt-get install -y curl
		fi

		curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash || {
			# If that fails, try the package manager
			sudo apt-get update
			sudo apt-get install -y zoxide || return 1
		}
		;;
	dnf)
		sudo dnf install -y zoxide
		;;
	pacman)
		sudo pacman -Sy --noconfirm zoxide
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, cannot install via package manager"
		return 1
		;;
	esac

	# Check if installation succeeded
	if command -v zoxide >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
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
	sudo git reset --hard || warn "Failed to reset git repository"
	sudo git clean -fd || warn "Failed to clean git repository"

	# Configure git trust for this repository
	(cd "$build_dir" && sudo git config --local --bool core.trustctime false)
	sudo chmod -R g+w "$build_dir"

	# Checkout appropriate version
	if [ "$version_type" = "stable" ]; then
		# Try to get latest tag
		local latest_version=$(git tag -l | grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -n1)

		if [ -n "$latest_version" ]; then
			info "Building version: $latest_version"
			sudo git checkout "$latest_version" || error "Failed to checkout version $latest_version"
		else
			info "No version tags found, using master branch"
			sudo git checkout master || sudo git checkout main || error "Failed to checkout master branch"
		fi
	else
		info "Building from latest HEAD"
		sudo git checkout master || sudo git checkout main || error "Failed to checkout master/main branch"
	fi

	info "Building $TOOL_NAME..."
	# Configure build flags for Rust
	configure_build_flags
	export CARGO_BUILD_JOBS="${MAKE_FLAGS#-j}"

	# Build with cargo
	sudo -E env CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" cargo build --release || error "Failed to build"

	info "Installing $TOOL_NAME..."
	sudo install -m755 target/release/zoxide "$BASE_DIR/bin/" || error "Failed to install"

	# Install shell completions system-wide
	sudo mkdir -p "$BASE_DIR/share/zsh/site-functions"
	sudo mkdir -p "$BASE_DIR/share/bash-completion/completions"
	sudo mkdir -p "$BASE_DIR/share/fish/vendor_completions.d"

	# Generate completions
	if [ -f "$BASE_DIR/bin/zoxide" ]; then
		# ZSH completions
		"$BASE_DIR/bin/zoxide" init zsh --cmd cd >/tmp/zoxide.zsh
		sudo mv /tmp/zoxide.zsh "$BASE_DIR/share/zsh/site-functions/_zoxide"

		# Bash completions
		"$BASE_DIR/bin/zoxide" init bash --cmd cd >/tmp/zoxide.bash
		sudo mv /tmp/zoxide.bash "$BASE_DIR/share/bash-completion/completions/zoxide"

		# Fish completions
		"$BASE_DIR/bin/zoxide" init fish --cmd cd >/tmp/zoxide.fish
		sudo mv /tmp/zoxide.fish "$BASE_DIR/share/fish/vendor_completions.d/zoxide.fish"
	fi
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting installation of $TOOL_NAME..."

	# Parse tool configuration
	parse_tool_config "$TOOL_NAME"

	# Detect if we should use package manager
	local use_pkg_manager=0
	if [ "$TOOL_VERSION_TYPE" = "managed" ]; then
		use_pkg_manager=1
	fi

	# For macOS with Homebrew, prefer package manager by default
	if [ "$OS_TYPE" = "macos" ] && [ "$PACKAGE_MANAGER" = "brew" ] && [ "$TOOL_VERSION_TYPE" != "head" ]; then
		info "On macOS with Homebrew, using package manager by default"
		use_pkg_manager=1
	fi

	if [ $use_pkg_manager -eq 1 ]; then
		if install_via_package_manager; then
			info "$TOOL_NAME successfully installed via package manager"
			return 0
		else
			warn "Package manager installation failed, falling back to build from source"
		fi
	fi

	# Install dependencies
	install_deps

	# Setup repository in cache
	REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

	# Build and install
	build_tool "$REPO_DIR" "$TOOL_VERSION_TYPE"

	info "$TOOL_NAME installation completed successfully"
}

# Run the main installation
main
