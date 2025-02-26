#!/usr/bin/env bash

###############################################################################
# Yazi Installation Script
#
# Purpose:
# Installs or updates yazi (https://github.com/sxyazi/yazi)
# A terminal file manager
#
# Dependencies:
# - Rust toolchain (automatically managed)
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="yazi"
REPO_URL="https://github.com/sxyazi/yazi"
BINARY="yazi"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."

	case "$OS_TYPE" in
	macos)
		if command -v brew >/dev/null 2>&1; then
			brew install pkg-config ffmpeg poppler fd ripgrep unar jq
		else
			warn "Homebrew not found, cannot install dependencies"
		fi
		;;
	*)
		case "$PACKAGE_MANAGER" in
		apt)
			sudo apt-get update
			sudo apt-get install -y pkg-config libmagic-dev libssl-dev libsqlite3-dev ffmpeg libpoppler-glib-dev libxcb1-dev \
				libxcb-shape0-dev libxcb-xfixes0-dev libasound2-dev fd-find ripgrep unar jq libfontconfig-dev
			;;
		dnf)
			sudo dnf install -y pkg-config file-devel openssl-devel sqlite-devel ffmpeg poppler-glib-devel xcb-util-devel \
				alsa-lib-devel fd-find ripgrep unar jq fontconfig-devel
			;;
		pacman)
			sudo pacman -Sy --noconfirm pkg-config file openssl sqlite ffmpeg poppler-glib xcb-util \
				alsa-lib fd ripgrep unar jq fontconfig
			;;
		*)
			warn "Unknown package manager, trying to install dependencies manually"
			package_install "pkg-config"
			package_install "libmagic-dev"
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
			sudo git checkout "$latest_version" || {
				warn "Failed to checkout version $latest_version, using main branch"
				sudo git checkout main || error "Failed to checkout main branch"
			}
		else
			info "No version tags found, using main branch"
			sudo git checkout main || error "Failed to checkout main branch"
		fi
	else
		info "Building from latest HEAD"
		sudo git checkout main || {
			warn "Failed to checkout main branch, trying master"
			sudo git checkout master || error "Failed to checkout master branch"
		}
	fi

	# Make sure Rust is available
	ensure_rust_available || error "Rust is required to build yazi"

	info "Building $TOOL_NAME..."
	# Configure build flags for Rust
	configure_build_flags
	export CARGO_BUILD_JOBS="${MAKE_FLAGS#-j}"

	# Build with cargo - on macOS we might not need sudo
	if [ "$OS_TYPE" = "macos" ]; then
		# For macOS, prefer using the current user's environment
		RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}" \
			CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}" \
			CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" \
			cargo build --release || error "Failed to build"
	else
		# For Linux, use sudo with environment vars passed through
		sudo -E env PATH="$PATH" \
			RUSTUP_HOME="${RUSTUP_HOME:-$BASE_DIR/share/dev/toolchains/rust/rustup}" \
			CARGO_HOME="${CARGO_HOME:-$BASE_DIR/share/dev/toolchains/rust/cargo}" \
			CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" \
			cargo build --release || error "Failed to build"
	fi

	info "Installing $TOOL_NAME..."
	# Ensure binary is available
	if [ -f "target/release/yazi" ]; then
		sudo install -m755 target/release/yazi "$BASE_DIR/bin/" || error "Failed to install"
		info "Successfully installed yazi to $BASE_DIR/bin/"
	else
		error "Binary not found at target/release/yazi after build"
	fi
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

	# Build and install
	build_tool "$REPO_DIR" "$TOOL_VERSION_TYPE"

	info "$TOOL_NAME installation completed successfully"
}

# Run the main installation
main
