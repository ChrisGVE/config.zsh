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
		package_install "make"
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

	# List all tags excluding 'latest'
	local all_tags=$(git tag -l | grep -v "^latest$")

	# Create a temporary file to store normalized tags
	local temp_file=$(mktemp)

	# Process each tag to normalize format (strip 'v' prefix if exists)
	echo "$all_tags" | while read -r tag; do
		if [[ "$tag" =~ ^v[0-9] ]]; then
			# Remove 'v' prefix for sorting
			echo "${tag#v}|$tag" >>"$temp_file"
		elif [[ "$tag" =~ ^[0-9] ]]; then
			# Keep version as is for sorting
			echo "$tag|$tag" >>"$temp_file"
		fi
	done

	# Sort by normalized version and get the original tag name of the latest version
	if [ -s "$temp_file" ]; then
		local latest_tag=$(sort -V -t'|' -k1 "$temp_file" | tail -n1 | cut -d'|' -f2)
		rm "$temp_file"
		echo "$latest_tag"
	else
		rm "$temp_file"
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
			info "No version tags found, trying to manually check for versions 0.10.x"

			# Try specific versions we know exist, starting from newest
			for ver in "v0.10.6" "v0.10.5" "v0.10.4" "v0.10.3" "v0.10.2" "v0.10.1" "v0.10.0"; do
				if sudo git tag -l | grep -q "^$ver$"; then
					info "Found version $ver, using it"
					sudo git checkout "$ver" || continue
					latest_version="$ver"
					break
				fi
			done

			if [ -z "$latest_version" ]; then
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
