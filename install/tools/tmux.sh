#!/usr/bin/env bash

###############################################################################
# Tmux Installation Script
#
# Purpose:
# Installs or updates tmux (https://github.com/tmux/tmux)
# A terminal multiplexer
#
# Dependencies:
# - libevent
# - ncurses
# - build tools
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="tmux"
REPO_URL="https://github.com/tmux/tmux"
BINARY="tmux"
VERSION_CMD="-V"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install libevent ncurses automake pkg-config
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y libevent-dev libncurses-dev automake pkg-config build-essential bison
		;;
	dnf)
		sudo dnf install -y libevent-devel ncurses-devel automake pkg-config make gcc bison
		;;
	pacman)
		sudo pacman -Sy --noconfirm libevent ncurses automake pkg-config make gcc bison
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, trying to install dependencies manually"
		package_install "libevent-dev"
		package_install "libncurses-dev"
		package_install "automake"
		package_install "pkg-config"
		package_install "build-essential"
		package_install "bison"
		;;
	esac
}

install_via_package_manager() {
	info "Installing $TOOL_NAME via package manager..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install tmux
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y tmux
		;;
	dnf)
		sudo dnf install -y tmux
		;;
	pacman)
		sudo pacman -Sy --noconfirm tmux
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, cannot install via package manager"
		return 1
		;;
	esac

	# Check if installation succeeded
	if command -v tmux >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

remove_package_manager_version() {
	info "Removing package manager version of $TOOL_NAME..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew uninstall tmux || true
		;;
	apt)
		sudo apt-get remove -y tmux || true
		;;
	dnf)
		sudo dnf remove -y tmux || true
		;;
	pacman)
		sudo pacman -R --noconfirm tmux || true
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, cannot remove via package manager"
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

	# Fetch all tags to ensure we get the latest
	sudo git fetch --tags --force || warn "Failed to fetch tags"

	# Checkout appropriate version
	if [ "$version_type" = "stable" ]; then
		# Get all tags and match the most recent digit-only tag
		local latest_version=$(git tag -l | grep -E '^[0-9]+(\.[0-9]+)*[a-z]?$' | sort -V | tail -n1)

		if [ -z "$latest_version" ]; then
			error "No valid version tags found"
		fi

		info "Building version: $latest_version"
		sudo git checkout "$latest_version" || error "Failed to checkout version $latest_version"
	else
		info "Building from latest HEAD"
		sudo git checkout master 2>/dev/null || sudo git checkout main || error "Failed to checkout master/main branch"
		# Pull latest changes
		sudo git pull --ff-only || warn "Failed to pull latest changes"
	fi

	info "Building $TOOL_NAME..."

	# Generate autotools files
	sh autogen.sh || error "Failed to generate build system"

	# Configure build flags
	configure_build_flags

	# Configure and build
	./configure --prefix="$BASE_DIR" || error "Failed to configure"
	make $MAKE_FLAGS || error "Failed to build"

	info "Installing $TOOL_NAME..."
	sudo make install || error "Failed to install"
}

###############################################################################
# Main Installation Process
###############################################################################

# Parse tool configuration
parse_tool_config "$TOOL_NAME"
info "Configured $TOOL_NAME version type: $TOOL_VERSION_TYPE"

# Check if already installed via package manager
is_installed_via_pkg=0
if command -v tmux >/dev/null 2>&1; then
	if which tmux | grep -q "/usr/bin/"; then
		is_installed_via_pkg=1
		info "Detected package manager installation of tmux"
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
	install_via_package_manager
	exit $?
fi

# For stable or head, build from source
info "Building $TOOL_NAME from source as configured ($TOOL_VERSION_TYPE)..."

# Install dependencies first
install_deps

# Setup repository in cache
REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

# Run installation/update
build_tool "$REPO_DIR" "$TOOL_VERSION_TYPE"

info "$TOOL_NAME installation completed successfully"
