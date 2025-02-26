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
	ensure_rust_available || error "Rust is required to build delta"
}

install_via_package_manager() {
	info "Installing $TOOL_NAME via package manager..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install git-delta
		;;
	apt)
		if [ "$OS_TYPE" = "raspberrypi" ] && [ "$(uname -m)" = "aarch64" ]; then
			# On Raspberry Pi, try to get the latest release from GitHub
			local latest_release=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest |
				grep -oP '"tag_name": "\K(.*)(?=")' || echo "")

			if [ -n "$latest_release" ]; then
				local version=${latest_release#v}
				local deb_file="git-delta_${version}_arm64.deb"
				local github_url="https://github.com/dandavison/delta/releases/download/$latest_release"

				# Try to download deb file
				info "Attempting to download pre-built package for ARM64..."
				if curl -L -o "/tmp/$deb_file" "$github_url/$deb_file"; then
					info "Installing from deb package..."
					sudo dpkg -i "/tmp/$deb_file" || warn "Failed to install deb package"
					rm -f "/tmp/$deb_file"
					return 0
				fi
			fi
		fi

		# Fall back to apt package if available
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

	# Check if installation succeeded
	if command -v delta >/dev/null 2>&1; then
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

	# Configure build flags for Rust
	configure_build_flags
	export CARGO_BUILD_JOBS="${MAKE_FLAGS#-j}"

	# For Raspberry Pi, limit resource usage
	if [ "$OS_TYPE" = "raspberrypi" ]; then
		info "Limiting build resources for Raspberry Pi..."
		export CARGO_BUILD_JOBS=1
		export RUSTFLAGS="-C codegen-units=1"
	fi

	# Make sure RUSTUP_HOME and CARGO_HOME are set correctly
	export RUSTUP_HOME="${RUSTUP_HOME:-$BASE_DIR/share/dev/toolchains/rust/rustup}"
	export CARGO_HOME="${CARGO_HOME:-$BASE_DIR/share/dev/toolchains/rust/cargo}"

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
	sudo install -m755 target/release/delta "$BASE_DIR/bin/" || error "Failed to install"

	return 0
}

###############################################################################
# Post-Installation Configuration
###############################################################################

configure_git() {
	info "Configuring git to use delta..."

	# Configure git globally
	git config --global core.pager delta
	git config --global interactive.diffFilter "delta --color-only"
	git config --global delta.navigate true
	git config --global merge.conflictStyle zdiff3

	info "Git configuration complete"
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

			# Configure git
			if [ -n "$TOOL_POST_COMMAND" ]; then
				info "Running post-installation command from tools.conf"
				eval "$TOOL_POST_COMMAND" || warn "Post-installation command failed"
			else
				# Default git configuration
				configure_git
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

	# Configure git
	if [ -n "$TOOL_POST_COMMAND" ]; then
		info "Running post-installation command from tools.conf"
		eval "$TOOL_POST_COMMAND" || warn "Post-installation command failed"
	else
		# Default git configuration
		configure_git
	fi

	info "$TOOL_NAME installation completed successfully"
}

# Run the main installation
main
