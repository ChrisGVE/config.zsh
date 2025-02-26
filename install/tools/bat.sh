#!/usr/bin/env bash

###############################################################################
# Bat Installation Script
#
# Purpose:
# Installs or updates the bat utility (https://github.com/sharkdp/bat)
# A cat clone with syntax highlighting and Git integration
#
# Dependencies:
# - Rust toolchain (automatically managed)
# - Basic build tools (cmake, pkg-config)
#
# Platform-specific notes:
# - On Debian-based systems, creates bat -> batcat symlink
# - On macOS, uses Homebrew if available
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="bat"
REPO_URL="https://github.com/sharkdp/bat"
BINARY="bat"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install cmake pkg-config
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y cmake pkg-config libssl-dev
		;;
	dnf)
		sudo dnf install -y cmake pkg-config openssl-devel
		;;
	pacman)
		sudo pacman -Sy --noconfirm cmake pkg-config openssl
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, trying to install dependencies manually"
		package_install "cmake"
		package_install "pkg-config"
		;;
	esac
}

install_via_package_manager() {
	info "Installing $TOOL_NAME via package manager..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install bat
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y bat

		# On Debian/Ubuntu the package might be called batcat
		if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
			info "bat installed as batcat, creating symlink"
			# Create symlink in user's bin directory
			mkdir -p "$HOME/.local/bin"
			ln -sf "$(which batcat)" "$HOME/.local/bin/bat"
			export PATH="$HOME/.local/bin:$PATH"

			# Also create system-wide symlink
			create_managed_symlink "$(which batcat)" "$BASE_DIR/bin/bat"
		fi
		;;
	dnf)
		sudo dnf install -y bat
		;;
	pacman)
		sudo pacman -Sy --noconfirm bat
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, cannot install via package manager"
		return 1
		;;
	esac

	# Check if installation succeeded
	if command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1; then
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
	sudo install -m755 target/release/bat "$BASE_DIR/bin/" || error "Failed to install"

	# Create bat -> batcat symlink if using Debian-based system
	if [ "$PACKAGE_MANAGER" = "apt" ]; then
		create_managed_symlink "$BASE_DIR/bin/bat" "$BASE_DIR/bin/batcat"
	fi

	return 0
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting installation of $TOOL_NAME..."

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

	# If bat-extras is required, set up for it
	if grep -q "^bat-extras=" "$TOOLS_CONF" 2>/dev/null; then
		info "bat-extras is configured, ensuring bat cache is built..."

		# Build the syntax highlighting cache
		if command -v bat >/dev/null 2>&1; then
			bat cache --build >/dev/null 2>&1 || warn "Failed to build bat cache"
		elif command -v batcat >/dev/null 2>&1; then
			batcat cache --build >/dev/null 2>&1 || warn "Failed to build bat cache"
		fi
	fi
}

# Parse tool configuration
parse_tool_config "$TOOL_NAME"

# Run the main installation
main
