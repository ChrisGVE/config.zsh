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

	case "$OS_TYPE" in
	macos)
		if command -v brew >/dev/null 2>&1; then
			brew install cmake pkg-config
		else
			warn "Homebrew not found, cannot install dependencies"
		fi
		;;
	*)
		case "$PACKAGE_MANAGER" in
		apt)
			sudo apt-get update
			sudo apt-get install -y cmake pkg-config
			;;
		dnf)
			sudo dnf install -y cmake pkg-config
			;;
		pacman)
			sudo pacman -Sy --noconfirm cmake pkg-config
			;;
		*)
			warn "Unknown package manager, trying to install dependencies manually"
			package_install "cmake"
			package_install "pkg-config"
			;;
		esac
		;;
	esac

	# Ensure Rust is available
	ensure_rust_available || error "Rust is required to build bat"
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
	(cd "$build_dir" && sudo git config --local core.trustctime false)
	sudo chmod -R g+w "$build_dir"

	# Check if the repository uses main or master branch
	local default_branch="master"
	if sudo git show-ref --verify --quiet refs/heads/main; then
		default_branch="main"
	fi

	# Checkout appropriate version
	if [ "$version_type" = "stable" ]; then
		# Try to get latest tag
		local latest_version=$(git tag -l | grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -n1)

		if [ -n "$latest_version" ]; then
			info "Building version: $latest_version"
			sudo git checkout "$latest_version" || error "Failed to checkout version $latest_version"
		else
			info "No version tags found, using $default_branch branch"
			sudo git checkout $default_branch || error "Failed to checkout $default_branch branch"
		fi
	else
		info "Building from latest HEAD"
		sudo git checkout $default_branch || error "Failed to checkout $default_branch branch"
	fi

	info "Building $TOOL_NAME..."

	# For Raspberry Pi, try to use pre-built release if available
	if [ "$OS_TYPE" = "raspberrypi" ] && [ "$(uname -m)" = "aarch64" ]; then
		info "Checking for pre-built binary for Raspberry Pi..."

		# Get version without 'v' prefix if it exists
		local version=${latest_version#v}

		# Try to find deb/rpm package from GitHub releases
		if [ -n "$latest_version" ]; then
			local github_url="https://github.com/sharkdp/bat/releases/download/$latest_version"
			local deb_file="bat_${version}_arm64.deb"

			# Try to download deb file
			info "Attempting to download pre-built package for ARM64..."
			if curl -L -o "/tmp/$deb_file" "$github_url/$deb_file"; then
				info "Installing from deb package..."
				sudo dpkg -i "/tmp/$deb_file" || warn "Failed to install deb package"
				rm -f "/tmp/$deb_file"

				# Create bat -> batcat symlink if needed
				if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
					create_managed_symlink "$(which batcat)" "$BASE_DIR/bin/bat"
				fi

				return 0
			else
				info "Pre-built package not found, building from source"
			fi
		fi
	fi

	# Configure build flags for Rust
	configure_build_flags
	export CARGO_BUILD_JOBS="${MAKE_FLAGS#-j}"

	# Make sure RUSTUP_HOME and CARGO_HOME are set correctly
	export RUSTUP_HOME="${RUSTUP_HOME:-$BASE_DIR/share/dev/toolchains/rust/rustup}"
	export CARGO_HOME="${CARGO_HOME:-$BASE_DIR/share/dev/toolchains/rust/cargo}"

	# Build with cargo - use sudo only if needed
	if [ "$OS_TYPE" = "macos" ]; then
		# On macOS, use the user's current environment
		RUSTUP_HOME="$RUSTUP_HOME" \
			CARGO_HOME="$CARGO_HOME" \
			CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" \
			cargo build --release || error "Failed to build"
	else
		# On Linux, use sudo with environment
		sudo -E env PATH="$PATH" \
			RUSTUP_HOME="$RUSTUP_HOME" \
			CARGO_HOME="$CARGO_HOME" \
			CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" \
			cargo build --release || error "Failed to build"
	fi

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

	# For Raspberry Pi, try the package manager first for speed/simplicity
	if [ "$OS_TYPE" = "raspberrypi" ] && [ "$TOOL_VERSION_TYPE" != "head" ]; then
		info "On Raspberry Pi, trying package manager first"
		use_pkg_manager=1
	fi

	if [ $use_pkg_manager -eq 1 ]; then
		if install_via_package_manager; then
			info "$TOOL_NAME successfully installed via package manager"

			# Build the cache if installed successfully
			if command -v bat >/dev/null 2>&1; then
				bat cache --build >/dev/null 2>&1 || true
			elif command -v batcat >/dev/null 2>&1; then
				batcat cache --build >/dev/null 2>&1 || true
			fi

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

	# Build the cache
	if command -v bat >/dev/null 2>&1; then
		bat cache --build >/dev/null 2>&1 || true
	elif command -v batcat >/dev/null 2>&1; then
		batcat cache --build >/dev/null 2>&1 || true
	fi

	info "$TOOL_NAME installation completed successfully"
}

# Run the main installation
main
