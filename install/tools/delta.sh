#!/usr/bin/env bash

###############################################################################
# Delta Installation Script
#
# Purpose:
# Installs or updates delta (https://github.com/dandavison/delta)
# A syntax-highlighting pager for git, diff, and grep output
#
# Dependencies:
# - Rust toolchain (automatically managed)
# - Basic build tools (cmake, pkg-config)
#
# Post-Installation:
# Configures git to use delta:
# - core.pager = delta
# - interactive.diffFilter = delta --color-only
# - delta.navigate = true
# - merge.conflictStyle = zdiff3
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="delta"
REPO_URL="https://github.com/dandavison/delta"
BINARY="delta"
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
		package_install "libssl-dev"
		;;
	esac

	# Ensure Rust is available
	ensure_rust_available || error "Rust is required to build delta"
}

install_via_package_manager() {
	info "Installing $TOOL_NAME via package manager..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install git-delta
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y git-delta
		;;
	dnf)
		sudo dnf install -y git-delta
		;;
	pacman)
		sudo pacman -Sy --noconfirm git-delta
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, cannot install via package manager"
		return 1
		;;
	esac

	# Check if installation succeeded - use extended checks for different package names
	if command -v delta >/dev/null 2>&1; then
		info "delta command found after package installation"
		return 0
	else
		# Some distributions might install it under a different name
		if command -v git-delta >/dev/null 2>&1; then
			info "git-delta command found, creating symlink to delta"
			sudo ln -sf "$(which git-delta)" "$BASE_DIR/bin/delta"
			return 0
		else
			warn "delta command not found after package installation"
			return 1
		fi
	fi
}

remove_package_manager_version() {
	info "Removing package manager version of $TOOL_NAME..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew uninstall git-delta || true
		;;
	apt)
		sudo apt-get remove -y git-delta || true
		;;
	dnf)
		sudo dnf remove -y git-delta || true
		;;
	pacman)
		sudo pacman -R --noconfirm git-delta || true
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, cannot remove via package manager"
		;;
	esac

	# Remove any symlinks that might exist
	if [ -L "$BASE_DIR/bin/delta" ]; then
		info "Removing existing delta symlink"
		sudo rm -f "$BASE_DIR/bin/delta"
	fi
}

download_prebuilt_binary() {
	if [ "$OS_TYPE" != "raspberrypi" ]; then
		return 1
	fi

	info "Attempting to download pre-built binary for Raspberry Pi..."

	# Get latest release info
	local releases_url="https://api.github.com/repos/dandavison/delta/releases/latest"
	local release_info=$(curl -s "$releases_url")

	# Extract version
	local version=$(echo "$release_info" | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)

	if [ -z "$version" ]; then
		warn "Could not determine latest delta version"
		return 1
	fi

	info "Latest version: $version"
	version=${version#v} # Remove 'v' prefix if present

	# For ARM64 Raspberry Pi
	if [ "$(uname -m)" = "aarch64" ]; then
		local deb_file="git-delta_${version}_arm64.deb"
		local github_url="https://github.com/dandavison/delta/releases/download/${version}/$deb_file"

		# Create temp directory
		local tmp_dir=$(mktemp -d)

		# Try to download deb file
		info "Downloading ARM64 deb package from: $github_url"
		if curl -L -o "$tmp_dir/$deb_file" "$github_url"; then
			info "Installing from deb package..."
			sudo dpkg -i "$tmp_dir/$deb_file" || {
				warn "Failed to install deb package"
				rm -rf "$tmp_dir"
				return 1
			}

			# Check if installed as git-delta and create symlink if needed
			if command -v git-delta >/dev/null 2>&1 && ! command -v delta >/dev/null 2>&1; then
				info "Creating symlink from git-delta to delta"
				sudo ln -sf "$(which git-delta)" "$BASE_DIR/bin/delta"
			fi

			rm -rf "$tmp_dir"
			return 0
		else
			warn "Failed to download deb package"
			rm -rf "$tmp_dir"
		fi
	fi

	return 1
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

	# Check if the repository uses main or master branch
	local default_branch="master"
	if sudo git show-ref --verify --quiet refs/heads/main; then
		default_branch="main"
	fi
	info "Default branch: $default_branch"

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
		# Pull latest changes
		sudo git pull --ff-only || warn "Failed to pull latest changes"
	fi

	info "Building $TOOL_NAME..."

	# Configure build flags for Rust
	configure_build_flags

	# Set Raspberry Pi resource constraints if needed
	if [ "$OS_TYPE" = "raspberrypi" ]; then
		info "Configuring resource constraints for Raspberry Pi..."
		export CARGO_BUILD_JOBS=1
		export RUSTFLAGS="-C codegen-units=1 -C opt-level=s -C lto=thin"
	else
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

	# Build with cargo - use sudo only if needed
	if [ "$OS_TYPE" = "macos" ]; then
		# On macOS, use the user's current environment
		RUSTUP_HOME="$RUSTUP_HOME" \
			CARGO_HOME="$CARGO_HOME" \
			CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" \
			RUSTFLAGS="${RUSTFLAGS:-}" \
			cargo build --release || error "Failed to build"
	else
		# On Linux, use sudo with environment
		sudo -E env PATH="$PATH" \
			RUSTUP_HOME="$RUSTUP_HOME" \
			CARGO_HOME="$CARGO_HOME" \
			CARGO_BUILD_JOBS="$CARGO_BUILD_JOBS" \
			RUSTFLAGS="${RUSTFLAGS:-}" \
			cargo build --release || error "Failed to build"
	fi

	info "Installing $TOOL_NAME..."
	if [ -f "target/release/delta" ]; then
		sudo install -m755 target/release/delta "$BASE_DIR/bin/" || error "Failed to install"
		info "Successfully installed delta to $BASE_DIR/bin/"
	else
		error "Binary not found at target/release/delta after build"
	fi

	return 0
}

configure_git() {
	info "Configuring git to use delta..."

	# Check if git is installed
	if ! command -v git >/dev/null 2>&1; then
		warn "Git not found, skipping configuration"
		return 1
	fi

	# Check if delta is installed
	if ! command -v delta >/dev/null 2>&1; then
		warn "Delta command not found, skipping git configuration"
		return 1
	fi

	info "Setting git configuration..."

	# Configure git globally
	git config --global core.pager delta || warn "Failed to set git core.pager"
	git config --global interactive.diffFilter "delta --color-only" || warn "Failed to set git interactive.diffFilter"
	git config --global delta.navigate true || warn "Failed to set git delta.navigate"
	git config --global merge.conflictStyle zdiff3 || warn "Failed to set git merge.conflictStyle"

	info "Git configuration complete"
	return 0
}

###############################################################################
# Main Installation Process
###############################################################################

# Parse tool configuration
parse_tool_config "$TOOL_NAME"
info "Configured $TOOL_NAME version type: $TOOL_VERSION_TYPE"

# Check if already installed via package manager
is_installed_via_pkg=0
if command -v delta >/dev/null 2>&1; then
	if which delta | grep -q "/usr/bin/"; then
		is_installed_via_pkg=1
		info "Detected package manager installation of delta"
	fi
elif command -v git-delta >/dev/null 2>&1; then
	if which git-delta | grep -q "/usr/bin/"; then
		is_installed_via_pkg=1
		info "Detected package manager installation of git-delta"
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

		# Configure git
		if [ -n "$TOOL_POST_COMMAND" ]; then
			info "Running post-installation command from tools.conf"
			eval "$TOOL_POST_COMMAND" || warn "Post-installation command failed"
		else
			# Default git configuration
			configure_git
		fi

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

		# Configure git
		if [ -n "$TOOL_POST_COMMAND" ]; then
			info "Running post-installation command from tools.conf"
			eval "$TOOL_POST_COMMAND" || warn "Post-installation command failed"
		else
			# Default git configuration
			configure_git
		fi

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
info "Building $TOOL_NAME from source..."
build_tool "$REPO_DIR" "$TOOL_VERSION_TYPE"

# Configure git
if [ -n "$TOOL_POST_COMMAND" ]; then
	info "Running post-installation command from tools.conf"
	eval "$TOOL_POST_COMMAND" || warn "Post-installation command failed"
else
	# Default git configuration
	configure_git
fi

info "$TOOL_NAME installation completed successfully"
