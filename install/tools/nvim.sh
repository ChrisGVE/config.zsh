#!/usr/bin/env bash

###############################################################################
# Neovim Installation Script
#
# Purpose:
# Installs or updates Neovim (https://neovim.io)
# A hyperextensible Vim-based text editor
#
# Dependencies:
# - Ninja build system
# - CMake
# - Various build dependencies
#
# Features:
# - Supports both 'stable' and 'head' versions
# - Properly detects current version
# - Handles version switching
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="nvim"
REPO_URL="https://github.com/neovim/neovim"
BINARY="nvim"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install ninja gettext cmake unzip curl automake
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y ninja-build gettext cmake unzip curl pkg-config automake libtool libtool-bin
		;;
	dnf)
		sudo dnf install -y ninja-build gettext cmake unzip curl pkg-config automake libtool
		;;
	pacman)
		sudo pacman -Sy --noconfirm ninja gettext cmake unzip curl pkg-config automake libtool
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, trying to install dependencies manually"
		package_install "ninja-build"
		package_install "gettext"
		package_install "cmake"
		package_install "unzip"
		package_install "curl"
		package_install "pkg-config"
		package_install "automake"
		package_install "libtool"
		;;
	esac
}

# Get the currently installed nvim version (if any)
get_nvim_version() {
	if command -v nvim >/dev/null 2>&1; then
		# Get version string
		local version_string=$(nvim --version | head -1)

		# Extract version number
		if [[ "$version_string" =~ v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
			echo "${BASH_REMATCH[1]}"
		else
			# If using a development version, try to get commit hash
			if [[ "$version_string" =~ dev-([0-9a-f]+) ]]; then
				echo "dev-${BASH_REMATCH[1]}"
			else
				echo "unknown"
			fi
		fi
	else
		echo ""
	fi
}

# Determine if we need to clean build
need_clean_build() {
	local current_version="$1"
	local target_version_type="$2"
	local current_is_dev=0

	# If current version is dev, it's from head
	if [[ "$current_version" == dev-* ]]; then
		current_is_dev=1
	fi

	# If switching between stable and head, clean build is needed
	if [[ "$target_version_type" == "stable" && $current_is_dev -eq 1 ]]; then
		return 0 # true
	elif [[ "$target_version_type" == "head" && $current_is_dev -eq 0 ]]; then
		return 0 # true
	fi

	# No need for clean build
	return 1 # false
}

build_tool() {
	local build_dir="$1"
	local version_type="$2"

	# Ensure build directory exists
	if [ ! -d "$build_dir" ]; then
		error "Build directory does not exist: $build_dir"
		return 1
	fi

	# Get current version
	local current_version=$(get_nvim_version)
	info "Current Neovim version: $current_version"

	# Enter build directory
	cd "$build_dir" || error "Failed to enter build directory: $build_dir"

	# Reset and clean the repository to handle any local changes
	sudo git reset --hard || warn "Failed to reset git repository"
	sudo git clean -fd || warn "Failed to clean git repository"

	# Configure git trust for this repository
	(cd "$build_dir" && sudo git config --local --bool core.trustctime false)
	sudo chmod -R g+w "$build_dir"

	# Checkout appropriate version
	local do_clean_build=0
	if [ "$version_type" = "stable" ]; then
		# Try to get latest tag
		local latest_version=$(git fetch --tags && git tag -l | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n1)

		if [ -n "$latest_version" ]; then
			info "Building version: $latest_version"
			sudo git checkout "$latest_version" || error "Failed to checkout version $latest_version"

			# Check if we need a clean build due to version type switch
			if need_clean_build "$current_version" "$version_type"; then
				info "Switching from development to stable version - performing clean build"
				do_clean_build=1
			fi
		else
			info "No version tags found, using master branch"
			sudo git checkout master || sudo git checkout main || error "Failed to checkout master branch"
		fi
	else
		info "Building from latest HEAD"
		sudo git checkout master || sudo git checkout main || error "Failed to checkout master/main branch"

		# Pull latest changes
		sudo git pull

		# Check if we need a clean build due to version type switch
		if need_clean_build "$current_version" "$version_type"; then
			info "Switching from stable to development version - performing clean build"
			do_clean_build=1
		fi
	fi

	info "Building $TOOL_NAME..."

	# Configure build flags
	configure_build_flags

	# Set CMAKE flags with optimizations
	CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=RelWithDebInfo \
                 -DCMAKE_INSTALL_PREFIX=$BASE_DIR \
                 -DENABLE_LTO=ON"

	# Clean if needed
	if [ $do_clean_build -eq 1 ]; then
		info "Performing clean build..."
		make clean || true
		rm -rf build/ || true
	fi

	# Build
	make $MAKE_FLAGS CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_FLAGS="$CMAKE_FLAGS" || {
		warn "Build failed, trying with clean build..."
		make clean || true
		rm -rf build/ || true
		make $MAKE_FLAGS CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_FLAGS="$CMAKE_FLAGS" || error "Failed to build"
	}

	info "Installing $TOOL_NAME..."
	sudo make install || error "Failed to install"

	# Verify installation
	if command -v nvim >/dev/null 2>&1; then
		local new_version=$(get_nvim_version)
		info "Successfully installed Neovim version: $new_version"
	else
		warn "Neovim binary not found in PATH after installation"
	fi
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting installation of $TOOL_NAME..."

	# Install dependencies
	install_deps

	# Set up repository in cache
	REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

	# Parse tool configuration
	parse_tool_config "$TOOL_NAME"

	# Build and install
	build_tool "$REPO_DIR" "$TOOL_VERSION_TYPE"

	info "$TOOL_NAME installation completed successfully"
}

# Run the main installation
main
