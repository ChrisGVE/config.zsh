#!/usr/bin/env bash

###############################################################################
# TV (Television) Installation Script
#
# Purpose:
# Installs or updates television (https://github.com/alexpasmantier/television)
# A terminal media player
#
# Dependencies:
# - Rust toolchain (automatically managed)
# - Make
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="tv"
REPO_URL="https://github.com/alexpasmantier/television"
BINARY="tv"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."

	# Ensure package manager is detected
	if type detect_package_manager >/dev/null 2>&1; then
		detect_package_manager
	fi

	# Set fallback if still not defined
	if [ -z "${PACKAGE_MANAGER:-}" ]; then
		warn "Package manager not detected, using fallback method"
		if command -v apt-get >/dev/null 2>&1; then
			PACKAGE_MANAGER="apt"
		elif command -v dnf >/dev/null 2>&1; then
			PACKAGE_MANAGER="dnf"
		elif command -v pacman >/dev/null 2>&1; then
			PACKAGE_MANAGER="pacman"
		elif command -v brew >/dev/null 2>&1; then
			PACKAGE_MANAGER="brew"
		else
			error "Could not determine package manager"
			return 1
		fi
		info "Using fallback package manager: $PACKAGE_MANAGER"
	fi

	case "$PACKAGE_MANAGER" in
	brew)
		brew install make
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y make
		;;
	dnf)
		sudo dnf install -y make
		;;
	pacman)
		sudo pacman -Sy --noconfirm make
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, trying to install dependencies manually"
		if command -v apt-get >/dev/null 2>&1; then
			sudo apt-get install -y make
		else
			error "Could not install dependencies"
			return 1
		fi
		;;
	esac
}

find_all_binaries() {
	local binary_name="$1"

	# Use which to find all instances of the binary in PATH
	which -a "$binary_name" 2>/dev/null || true
}

remove_old_binaries() {
	local binary_name="$1"
	local bin_path="$2"

	# Find all instances of the binary
	local binaries=($(find_all_binaries "$binary_name"))

	info "Found ${#binaries[@]} instances of $binary_name:"
	for b in "${binaries[@]}"; do
		info "  - $b"

		# Skip our managed binary
		if [ "$b" = "$bin_path" ]; then
			continue
		fi

		# Handle binaries in system locations
		if [[ "$b" == "/usr/bin/"* ]]; then
			info "Removing package-installed binary at $b"
			sudo rm -f "$b" || warn "Failed to remove $b"
		elif [[ "$b" == "$HOME"* ]]; then
			info "Removing user-installed binary at $b"
			rm -f "$b" || warn "Failed to remove $b"
		fi
	done
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

	# Configure git trust
	sudo git config --global --add safe.directory "$build_dir"

	# Checkout appropriate version
	if [ "$version_type" = "stable" ]; then
		# For stable, explicitly checkout 0.10.6 which we know is the latest
		info "Building stable version 0.10.6"
		sudo git checkout "0.10.6" || error "Failed to checkout version 0.10.6"
	else
		info "Building from latest HEAD"
		sudo git checkout main 2>/dev/null || sudo git checkout master || error "Failed to checkout main/master branch"

		# Pull latest changes
		sudo git pull --ff-only || warn "Failed to pull latest changes"
	fi

	info "Building $TOOL_NAME..."

	# Configure build flags for Rust with resource constraints
	configure_build_flags

	# Limit parallelism for Raspberry Pi
	if [ "$OS_TYPE" = "raspberrypi" ]; then
		info "Configuring resource constraints for Raspberry Pi..."
		export CARGO_BUILD_JOBS=1
		export RUSTFLAGS="-C codegen-units=1 -C opt-level=s"
	else
		export CARGO_BUILD_JOBS="${MAKE_FLAGS#-j}"
	fi

	# Make sure RUSTUP_HOME and CARGO_HOME are set correctly
	export RUSTUP_HOME="${RUSTUP_HOME:-$BASE_DIR/share/dev/toolchains/rust/rustup}"
	export CARGO_HOME="${CARGO_HOME:-$BASE_DIR/share/dev/toolchains/rust/cargo}"

	# Export PATH to include cargo
	export PATH="$PATH:$CARGO_HOME/bin"

	# Build using make as recommended
	make release || error "Failed to build"

	info "Installing $TOOL_NAME..."
	if [ -f "target/release/tv" ]; then
		# Install to our managed location
		sudo install -m755 target/release/tv "$BASE_DIR/bin/" || error "Failed to install"
		info "Successfully installed tv to $BASE_DIR/bin/"

		# Remove any other instances to avoid conflicts
		remove_old_binaries "tv" "$BASE_DIR/bin/tv"

		# Just to be sure, check the version
		if "$BASE_DIR/bin/tv" --version | grep -q "0.10.6"; then
			info "Successfully installed television 0.10.6"
		else
			warn "Installed version doesn't match expected 0.10.6"
			"$BASE_DIR/bin/tv" --version
		fi
	else
		error "Binary not found at target/release/tv after build"
	fi
}

###############################################################################
# Main Installation Process
###############################################################################

# Parse tool configuration
parse_tool_config "$TOOL_NAME"
info "Configured $TOOL_NAME version type: $TOOL_VERSION_TYPE"

# Check for all instances of TV in the PATH
info "Checking for existing TV installations..."
tv_binaries=($(find_all_binaries "tv"))
for bin in "${tv_binaries[@]}"; do
	version=$("$bin" --version 2>&1 | head -n1)
	info "Found $bin: $version"
done

# Make sure /opt/local/bin is first in PATH for this script
if [[ ":$PATH:" != *":$BASE_DIR/bin:"* ]]; then
	export PATH="$BASE_DIR/bin:$PATH"
	info "Added $BASE_DIR/bin to PATH"
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

# Ensure package manager is detected
if type detect_package_manager >/dev/null 2>&1; then
	detect_package_manager
	info "Using package manager: $PACKAGE_MANAGER"
fi

# Install dependencies
install_deps

# Setup repository in cache
REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

# Display version tags for debugging
cd "$REPO_DIR" || error "Failed to enter repository directory"
sudo git fetch --tags --force || warn "Failed to fetch tags"
info "Available tags in repository:"
sudo git tag -l | sort -V

# Build and install
build_tool "$REPO_DIR" "$TOOL_VERSION_TYPE"

info "$TOOL_NAME installation completed successfully"

# Verify the installation one more time
info "Verifying installation:"
if command -v tv >/dev/null 2>&1; then
	tv_path=$(which tv)
	tv_version=$(tv --version)
	info "Using TV at $tv_path: $tv_version"

	if [ "$tv_path" != "$BASE_DIR/bin/tv" ]; then
		warn "WARNING: Using TV from $tv_path instead of $BASE_DIR/bin/tv"
		warn "Please ensure $BASE_DIR/bin is early in your PATH"
	fi

	if [[ "$tv_version" != *"0.10.6"* ]]; then
		warn "WARNING: TV version is $tv_version, not the expected 0.10.6"
		warn "Run the following command to verify the installed version:"
		warn "  $BASE_DIR/bin/tv --version"
	fi
else
	warn "TV command not found in PATH after installation"
fi
