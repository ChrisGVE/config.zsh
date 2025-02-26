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

forcefully_remove_binary() {
	local binary_path="$1"

	if [ -f "$binary_path" ]; then
		info "Forcefully removing binary at $binary_path"
		sudo rm -f "$binary_path" || {
			error "Failed to remove $binary_path with sudo"
			# Try with more aggressive permissions
			sudo chmod 777 "$(dirname "$binary_path")" || true
			sudo rm -f "$binary_path" || {
				error "Still failed to remove $binary_path"
				return 1
			}
		}
		return 0
	else
		info "Binary $binary_path does not exist"
		return 0
	fi
}

remove_competing_binaries() {
	# Explicitly remove known common locations
	forcefully_remove_binary "/usr/local/bin/tv"
	forcefully_remove_binary "/usr/bin/tv"
	forcefully_remove_binary "$HOME/.local/bin/tv"

	# Use which -a to find all other instances
	local other_binaries=$(which -a tv 2>/dev/null | grep -v "^$BASE_DIR/bin/tv$" || true)
	if [ -n "$other_binaries" ]; then
		info "Found additional TV binaries to remove:"
		echo "$other_binaries" | while read -r bin_path; do
			if [ -n "$bin_path" ] && [ "$bin_path" != "$BASE_DIR/bin/tv" ]; then
				forcefully_remove_binary "$bin_path"
			fi
		done
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
		# First, remove any competing TV binaries
		remove_competing_binaries

		# Install to our managed location
		sudo install -m755 target/release/tv "$BASE_DIR/bin/" || error "Failed to install"
		info "Successfully installed tv to $BASE_DIR/bin/"

		# Verify our installation by calling it directly
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

# Remove competing binaries one more time after installation
remove_competing_binaries

# Update system links
info "Making sure PATH is properly configured in shell..."
cat <<EOF >>"$HOME/.bashrc"

# Ensure /opt/local/bin is first in PATH for tools
export PATH="/opt/local/bin:\$PATH"
EOF

info "TV installation completed successfully - path updated in ~/.bashrc"
info "Run 'source ~/.bashrc' or open a new terminal to use the updated TV version"

# Verify the installation one more time
info "Verifying installation:"
if [ -f "$BASE_DIR/bin/tv" ]; then
	tv_version=$("$BASE_DIR/bin/tv" --version 2>&1 | head -n1)
	info "TV at $BASE_DIR/bin/tv: $tv_version"

	if [[ "$tv_version" != *"0.10.6"* ]]; then
		warn "WARNING: TV version is $tv_version, not the expected 0.10.6"
	else
		info "Correct version verified: $tv_version"
	fi
else
	warn "TV binary not found at $BASE_DIR/bin/tv after installation"
fi

# Final recommendation
echo ""
echo "===== IMPORTANT ====="
echo "To use the updated TV version immediately, run:"
echo "export PATH=\"/opt/local/bin:\$PATH\""
echo "Then verify with:"
echo "which tv"
echo "tv --version"
echo "=================="
