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
		# Try to determine package manager
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

install_via_package_manager() {
	info "Installing $TOOL_NAME via package manager..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install television
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y television
		;;
	dnf)
		sudo dnf install -y television
		;;
	pacman)
		sudo pacman -Sy --noconfirm television
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, cannot install via package manager"
		return 1
		;;
	esac

	# Check if installation succeeded
	if command -v tv >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

remove_package_manager_version() {
	info "Removing package manager version of $TOOL_NAME..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew uninstall television || true
		;;
	apt)
		sudo apt-get remove -y television || true
		;;
	dnf)
		sudo dnf remove -y television || true
		;;
	pacman)
		sudo pacman -R --noconfirm television || true
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, cannot remove via package manager"
		;;
	esac
}

find_latest_version_tag() {
	local repo_dir="$1"

	# Change to the repository directory
	cd "$repo_dir" || return

	# Ensure we have all tags
	sudo git fetch --tags --force || warn "Failed to fetch tags"

	# List all tags and filter for version-like tags
	local all_tags=$(git tag -l)
	info "Available tags: $all_tags"

	# Filter out 'latest' tag and look for numeric versions without 'v' prefix
	# For this repo, we want the plain version format (0.10.6, not v0.10.6)
	local version_tags=$(echo "$all_tags" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$')

	info "Version tags found: $version_tags"

	# Sort tags by version number and get the latest
	if [ -n "$version_tags" ]; then
		echo "$version_tags" | sort -V | tail -n1
	else
		# Return empty if no version tags found
		echo ""
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

	# Configure git trust
	sudo git config --global --add safe.directory "$build_dir"

	# Checkout appropriate version
	if [ "$version_type" = "stable" ]; then
		# Try to get latest version using the custom function
		local latest_version=$(find_latest_version_tag "$build_dir")

		if [ -n "$latest_version" ]; then
			info "Building version: $latest_version"
			sudo git checkout "$latest_version" || error "Failed to checkout version $latest_version"
		else
			info "No numeric version tags found, trying fallback to 0.10.6"
			if sudo git tag -l | grep -q "^0.10.6$"; then
				info "Found version 0.10.6, using it"
				sudo git checkout "0.10.6" || warn "Failed to checkout 0.10.6"
			else
				# If still not found, use main/master branch as fallback
				info "No known version tags found, using main/master branch"
				sudo git checkout main 2>/dev/null || sudo git checkout master || error "Failed to checkout main/master branch"
			fi
		fi
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
		sudo install -m755 target/release/tv "$BASE_DIR/bin/" || error "Failed to install"
		info "Successfully installed tv to $BASE_DIR/bin/"
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

# Check current installation
if command -v tv >/dev/null 2>&1; then
	current_version=$(tv --version 2>&1 | head -n1 | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" || echo "unknown")
	info "Currently installed tv version: $current_version"

	# Check if installed via package manager
	is_installed_via_pkg=0
	if which tv | grep -q "/usr/bin/"; then
		is_installed_via_pkg=1
		info "Detected package manager installation of tv"
	fi

	# If installed via package manager but we want stable/head, uninstall it
	if [ $is_installed_via_pkg -eq 1 ] && [ "$TOOL_VERSION_TYPE" != "managed" ]; then
		info "Removing package manager version before building from source..."
		remove_package_manager_version
	fi
else
	info "TV is not currently installed"
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
