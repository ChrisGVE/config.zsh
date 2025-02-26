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

install_via_package_manager() {
	info "Installing $TOOL_NAME via package manager..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install uv
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y uv
		;;
	dnf)
		sudo dnf install -y uv
		;;
	pacman)
		sudo pacman -Sy --noconfirm uv
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, cannot install via package manager"
		return 1
		;;
	esac

	# Check if installation succeeded
	if command -v uv >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

remove_package_manager_version() {
	info "Removing package manager version of $TOOL_NAME..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew uninstall uv || true
		;;
	apt)
		sudo apt-get remove -y uv || true
		;;
	dnf)
		sudo dnf remove -y uv || true
		;;
	pacman)
		sudo pacman -R --noconfirm uv || true
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, cannot remove via package manager"
		;;
	esac
}

download_prebuilt_binary() {
	info "Attempting to download pre-built binary..."

	# Get latest release info
	local releases_url="https://api.github.com/repos/astral-sh/uv/releases/latest"
	local release_info=$(curl -s "$releases_url")

	# Extract version
	local version=$(echo "$release_info" | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)

	if [ -z "$version" ]; then
		warn "Could not determine latest uv version"
		return 1
	fi

	info "Latest version: $version"

	# Determine platform and architecture
	local platform=""
	local arch=""

	case "$OS_TYPE" in
	macos)
		platform="apple-darwin"
		;;
	linux | raspberrypi)
		platform="unknown-linux-musl"
		;;
	*)
		warn "Unsupported platform: $OS_TYPE"
		return 1
		;;
	esac

	case "$(uname -m)" in
	x86_64)
		arch="x86_64"
		;;
	aarch64 | arm64)
		arch="aarch64"
		;;
	*)
		warn "Unsupported architecture: $(uname -m)"
		return 1
		;;
	esac

	# Construct download URL
	local download_url="https://github.com/astral-sh/uv/releases/download/${version}/uv-${arch}-${platform}.tar.gz"
	info "Download URL: $download_url"

	# Download and extract
	local tmp_dir=$(mktemp -d)
	if curl -L -o "$tmp_dir/uv.tar.gz" "$download_url"; then
		tar -xzf "$tmp_dir/uv.tar.gz" -C "$tmp_dir"

		# Find the binary
		local binary_path=$(find "$tmp_dir" -name "uv" -type f)

		if [ -z "$binary_path" ]; then
			warn "Could not find uv binary in extracted archive"
			rm -rf "$tmp_dir"
			return 1
		fi

		# Install binary
		sudo install -m755 "$binary_path" "$BASE_DIR/bin/" || {
			warn "Failed to install uv binary"
			rm -rf "$tmp_dir"
			return 1
		}

		rm -rf "$tmp_dir"
		info "Successfully installed pre-built uv binary"
		return 0
	else
		warn "Failed to download uv binary"
		rm -rf "$tmp_dir"
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

	# Fetch all tags
	sudo git fetch --tags --force || warn "Failed to fetch tags"

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
		# Pull latest changes
		sudo git pull --ff-only || warn "Failed to pull latest changes"
	fi

	# Make sure Rust is available
	ensure_rust_available || error "Rust is required to build uv"

	info "Building $TOOL_NAME..."

	# Configure with extreme resource constraints for Raspberry Pi
	if [ "$OS_TYPE" = "raspberrypi" ]; then
		info "Using extreme resource constraints for Raspberry Pi..."
		export CARGO_BUILD_JOBS=1
		export RUSTFLAGS="-C codegen-units=1 -C opt-level=s -C lto=thin"
	else
		# Configure build flags for Rust on other platforms
		configure_build_flags
		export CARGO_BUILD_JOBS="${MAKE_FLAGS#-j}"
	fi

	# Make sure RUSTUP_HOME and CARGO_HOME are set correctly
	export RUSTUP_HOME="${RUSTUP_HOME:-$BASE_DIR/share/dev/toolchains/rust/rustup}"
	export CARGO_HOME="${CARGO_HOME:-$BASE_DIR/share/dev/toolchains/rust/cargo}"

	# Add debugging info
	info "RUSTUP_HOME=$RUSTUP_HOME"
	info "CARGO_HOME=$CARGO_HOME"
	info "CARGO_BUILD_JOBS=$CARGO_BUILD_JOBS"
	info "RUSTFLAGS=${RUSTFLAGS:-none}"

	# Export PATH to include cargo
	export PATH="$PATH:$CARGO_HOME/bin"

	# For Raspberry Pi, build with minimal feature set
	if [ "$OS_TYPE" = "raspberrypi" ]; then
		info "Building with minimal features for Raspberry Pi..."
		# Build with cargo - use sudo with environment
		sudo -E env PATH="$PATH" \
			RUSTUP_HOME="$RUSTUP_HOME" \
			CARGO_HOME="$CARGO_HOME" \
			CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" \
			RUSTFLAGS="${RUSTFLAGS:-}" \
			cargo build --profile release-small --no-default-features --features "system-libs" || error "Failed to build"
	else
		# For other platforms, build with default features
		if [ "$OS_TYPE" = "macos" ]; then
			# For macOS, don't use sudo
			RUSTFLAGS="${RUSTFLAGS:-}" \
				CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" \
				cargo build --release || error "Failed to build"
		else
			# For Linux, use sudo with environment
			sudo -E env PATH="$PATH" \
				RUSTUP_HOME="$RUSTUP_HOME" \
				CARGO_HOME="$CARGO_HOME" \
				CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" \
				RUSTFLAGS="${RUSTFLAGS:-}" \
				cargo build --release || error "Failed to build"
		fi
	fi

	info "Installing $TOOL_NAME..."

	# Find the binary location based on build profile
	local bin_path="target/release/uv"
	if [ "$OS_TYPE" = "raspberrypi" ]; then
		bin_path="target/release-small/uv"
		# Check if it exists, otherwise fall back to release
		if [ ! -f "$bin_path" ]; then
			bin_path="target/release/uv"
		fi
	fi

	# Install the binary
	if [ -f "$bin_path" ]; then
		sudo install -m755 "$bin_path" "$BASE_DIR/bin/" || error "Failed to install"
		info "Successfully installed $TOOL_NAME to $BASE_DIR/bin/"
	else
		error "Binary not found at $bin_path after build"
	fi
}

###############################################################################
# Main Installation Process
###############################################################################

# Parse tool configuration
parse_tool_config "$TOOL_NAME"
info "Configured $TOOL_NAME version type: $TOOL_VERSION_TYPE"

# Check if already installed via package manager
is_installed_via_pkg=0
if command -v uv >/dev/null 2>&1; then
	if which uv | grep -q "/usr/bin/"; then
		is_installed_via_pkg=1
		info "Detected package manager installation of uv"
	fi
fi

# If installed via package manager but we want stable/head, uninstall it
if [ $is_installed_via_pkg -eq 1 ] && [ "$TOOL_VERSION_TYPE" != "managed" ]; then
	info "Removing package manager version before building from source..."
	remove_package_manager_version
fi

# Only use package manager if explicitly set to "managed"
if [ "$TOOL_VERSION_TYPE" = "managed" ]; then
	info "Installing $TOOL_NAME via package manager as configured..."
	if install_via_package_manager; then
		info "$TOOL_NAME successfully installed via package manager"
		exit 0
	else
		warn "Package manager installation failed, falling back to build from source"
	fi
fi

# For Raspberry Pi, try pre-built binary first
if [ "$OS_TYPE" = "raspberrypi" ]; then
	info "Trying pre-built binary for Raspberry Pi..."
	if download_prebuilt_binary; then
		info "$TOOL_NAME successfully installed using pre-built binary"
		exit 0
	else
		info "Pre-built binary installation failed, will try building from source"
	fi
fi

# Install dependencies
install_deps

# Setup repository in cache
REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

# Build and install
build_tool "$REPO_DIR" "$TOOL_VERSION_TYPE"

info "$TOOL_NAME installation completed successfully"
