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

	# Ensure Rust is available
	ensure_rust_available || error "Rust is required to build zoxide"
}

install_via_package_manager() {
	info "Installing $TOOL_NAME via package manager..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install zoxide
		;;
	apt)
		if [ "$OS_TYPE" = "raspberrypi" ] && [ "$(uname -m)" = "aarch64" ]; then
			# Try curl installer from official site first
			if curl -s https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash; then
				# Check if successful
				if command -v zoxide >/dev/null 2>&1; then
					info "Successfully installed zoxide using official installer"
					return 0
				fi
			fi
		fi

		# Fall back to apt package
		sudo apt-get update
		sudo apt-get install -y zoxide
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

install_using_official_script() {
	info "Attempting to install using zoxide's official installer script..."

	# Create a temporary directory for the installer
	local tmp_dir=$(mktemp -d)
	local install_script="$tmp_dir/install.sh"

	# Download the installer script
	if curl -s -o "$install_script" https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh; then
		chmod +x "$install_script"

		# Run the installer with custom install location
		bash "$install_script" -d "$BASE_DIR/bin"
		local install_status=$?

		# Clean up
		rm -rf "$tmp_dir"

		# Check if installation was successful
		if [ $install_status -eq 0 ] && command -v zoxide >/dev/null 2>&1; then
			info "Successfully installed zoxide using official installer"
			return 0
		else
			warn "Failed to install zoxide using official installer"
			return 1
		fi
	else
		warn "Failed to download zoxide installer script"
		rm -rf "$tmp_dir"
		return 1
	fi
}

download_prebuilt_binary() {
	info "Attempting to download pre-built binary..."

	# Get latest release info
	local releases_url="https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest"
	local release_info=$(curl -s "$releases_url")

	# Extract version and download URL
	local version=$(echo "$release_info" | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)

	if [ -z "$version" ]; then
		warn "Could not determine latest zoxide version"
		return 1
	fi

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
	local download_url="https://github.com/ajeetdsouza/zoxide/releases/download/${version}/zoxide-${arch}-${platform}.tar.gz"

	# Download and extract
	local tmp_dir=$(mktemp -d)
	if curl -L -o "$tmp_dir/zoxide.tar.gz" "$download_url"; then
		tar -xzf "$tmp_dir/zoxide.tar.gz" -C "$tmp_dir"

		# Install binary
		sudo install -m755 "$tmp_dir/zoxide" "$BASE_DIR/bin/" || {
			warn "Failed to install zoxide binary"
			rm -rf "$tmp_dir"
			return 1
		}

		rm -rf "$tmp_dir"
		return 0
	else
		warn "Failed to download zoxide binary"
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

	# Export PATH to include cargo
	export PATH="$PATH:$CARGO_HOME/bin"

	# Verify cargo is actually available
	if ! command -v cargo >/dev/null 2>&1; then
		error "Cargo not found in PATH: $PATH"
	fi

	# Show cargo version for debugging
	cargo --version || true

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

	return 0
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting installation of $TOOL_NAME..."

	# Parse tool configuration
	parse_tool_config "$TOOL_NAME"

	# Try official installer first, which handles OS and architecture detection
	if install_using_official_script; then
		info "$TOOL_NAME successfully installed using official installer"
		return 0
	fi

	# Try downloading pre-built binary
	if download_prebuilt_binary; then
		info "$TOOL_NAME successfully installed using pre-built binary"
		return 0
	fi

	# Try package manager next
	if [ "$TOOL_VERSION_TYPE" = "managed" ] || [ "$TOOL_VERSION_TYPE" = "stable" ]; then
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
