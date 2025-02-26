#!/usr/bin/env bash

###############################################################################
# TOOL_NAME Installation Script
#
# Purpose:
# Installs or updates TOOL_NAME (URL)
# Brief description of what the tool does
#
# Dependencies:
# - List dependencies here
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="tool-name"
REPO_URL="https://github.com/user/repo"
BINARY="binary-name"
VERSION_CMD="--version" # or -v, -V, etc.

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install dependency1 dependency2
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y dependency1 dependency2
		;;
	dnf)
		sudo dnf install -y dependency1 dependency2
		;;
	pacman)
		sudo pacman -Sy --noconfirm dependency1 dependency2
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, trying to install dependencies manually"
		package_install "dependency1"
		package_install "dependency2"
		;;
	esac
}

install_via_package_manager() {
	info "Installing $TOOL_NAME via package manager..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install tool-name
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y tool-name
		;;
	dnf)
		sudo dnf install -y tool-name
		;;
	pacman)
		sudo pacman -Sy --noconfirm tool-name
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, cannot install via package manager"
		return 1
		;;
	esac

	# Check if installation succeeded
	if command -v $BINARY >/dev/null 2>&1; then
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

	# TOOL-SPECIFIC BUILD STEPS GO HERE
	# Example for Rust project:
	configure_build_flags
	export CARGO_BUILD_JOBS="${MAKE_FLAGS#-j}"
	sudo -E env CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" cargo build --release || error "Failed to build"

	info "Installing $TOOL_NAME..."
	# TOOL-SPECIFIC INSTALL STEPS GO HERE
	# Example:
	sudo install -m755 target/release/$BINARY "$BASE_DIR/bin/" || error "Failed to install"

	return 0
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
