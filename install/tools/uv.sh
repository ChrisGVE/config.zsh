#!/usr/bin/env bash

###############################################################################
# UV Installation Script
#
# Purpose:
# Installs or updates uv (https://github.com/astral-sh/uv)
# A fast Python package installer and resolver
#
# Dependencies:
# - Rust toolchain (automatically managed)
# - pkg-config and SSL development files
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="uv"
REPO_URL="https://github.com/astral-sh/uv"
BINARY="uv"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."

	case "$OS_TYPE" in
	macos)
		if command -v brew >/dev/null 2>&1; then
			brew install cmake pkg-config openssl@1.1
		else
			warn "Homebrew not found, cannot install dependencies"
		fi
		;;
	*)
		case "$PACKAGE_MANAGER" in
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
			warn "Unknown package manager, trying to install dependencies manually"
			package_install "cmake"
			package_install "pkg-config"
			package_install "libssl-dev"
			;;
		esac
		;;
	esac
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

	# Checkout appropriate version
	if [ "$version_type" = "stable" ]; then
		# Try to get latest tag
		local latest_version=$(git tag -l | grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -n1)

		if [ -n "$latest_version" ]; then
			info "Building version: $latest_version"
			sudo git checkout "$latest_version" || error "Failed to checkout version $latest_version"
		else
			info "No version tags found, using main branch"
			sudo git checkout main || error "Failed to checkout main branch"
		fi
	else
		info "Building from latest HEAD"
		sudo git checkout main || error "Failed to checkout main branch"
	fi

	# Make sure Rust is available
	ensure_rust_available || error "Rust is required to build uv"

	info "Building $TOOL_NAME..."

	# Configure with limited resources for Raspberry Pi
	if [ "$OS_TYPE" = "raspberrypi" ]; then
		info "Limiting build resources for Raspberry Pi..."
		# Use only 1 job and limit memory usage
		export CARGO_BUILD_JOBS=1
		export RUSTFLAGS="-C codegen-units=1"
	else
		# Configure build flags for Rust on other platforms
		configure_build_flags
		export CARGO_BUILD_JOBS="${MAKE_FLAGS#-j}"
	fi

	# For Raspberry Pi, download pre-built binary if available
	if [ "$OS_TYPE" = "raspberrypi" ] && [ "$(uname -m)" = "aarch64" ]; then
		info "Attempting to download pre-built binary for Raspberry Pi..."

		# Get version without 'v' prefix if it exists
		local version=${latest_version#v}

		# Try to download pre-built binary
		local tmp_dir=$(mktemp -d)
		if curl -L "https://github.com/astral-sh/uv/releases/download/$latest_version/uv-aarch64-unknown-linux-gnu.tar.gz" -o "$tmp_dir/uv.tar.gz"; then
			# Extract and install
			tar -xzf "$tmp_dir/uv.tar.gz" -C "$tmp_dir"
			sudo install -m755 "$tmp_dir/uv" "$BASE_DIR/bin/" || error "Failed to install"
			rm -rf "$tmp_dir"
			info "Successfully installed pre-built uv binary"
			return 0
		else
			info "No pre-built binary available, falling back to compilation"
		fi
	fi

	# Build with cargo
	if [ "$OS_TYPE" = "macos" ]; then
		# For macOS, don't use sudo
		RUSTFLAGS="${RUSTFLAGS:-}" \
			CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" \
			cargo build --release || error "Failed to build"
	else
		# For Linux, use sudo with environment
		sudo -E env PATH="$PATH" \
			RUSTUP_HOME="${RUSTUP_HOME:-$BASE_DIR/share/dev/toolchains/rust/rustup}" \
			CARGO_HOME="${CARGO_HOME:-$BASE_DIR/share/dev/toolchains/rust/cargo}" \
			CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" \
			RUSTFLAGS="${RUSTFLAGS:-}" \
			cargo build --release || error "Failed to build"
	fi

	info "Installing $TOOL_NAME..."
	sudo install -m755 target/release/uv "$BASE_DIR/bin/" || error "Failed to install"
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting installation of $TOOL_NAME..."

	# Install dependencies
	install_deps

	# Setup repository in cache
	REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

	# Parse tool configuration
	parse_tool_config "$TOOL_NAME"

	# For Raspberry Pi, try to use a pre-built binary first
	if [ "$OS_TYPE" = "raspberrypi" ]; then
		info "Checking for pre-built binary for Raspberry Pi..."

		# Latest release URL
		RELEASE_URL="https://github.com/astral-sh/uv/releases/latest/download/uv-aarch64-unknown-linux-gnu.tar.gz"

		# Create temp directory
		local tmp_dir=$(mktemp -d)

		# Try to download pre-built binary
		if curl -L "$RELEASE_URL" -o "$tmp_dir/uv.tar.gz"; then
			info "Downloaded pre-built binary, installing..."
			tar -xzf "$tmp_dir/uv.tar.gz" -C "$tmp_dir"
			sudo install -m755 "$tmp_dir/uv" "$BASE_DIR/bin/" || warn "Failed to install pre-built binary, will build from source"
			rm -rf "$tmp_dir"
			info "Successfully installed pre-built uv binary"
			return 0
		else
			info "No pre-built binary available, will build from source"
		fi
	fi

	# Build and install
	build_tool "$REPO_DIR" "$TOOL_VERSION_TYPE"

	info "$TOOL_NAME installation completed successfully"
}

# Run the main installation
main
