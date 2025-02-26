#!/usr/bin/env bash

###############################################################################
# Bat-Extras Installation Script
#
# Purpose:
# Installs or updates bat-extras (https://github.com/eth-p/bat-extras)
# A collection of scripts that integrate with bat
#
# Dependencies:
# - bat (must be installed first)
# - shfmt (for script modifications)
#
# Installed Scripts:
# - batdiff (better git diff)
# - batgrep (better grep)
# - batman (better man)
# - batpipe (better pager)
# - batwatch (better watch)
# and more...
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="bat-extras"
REPO_URL="https://github.com/eth-p/bat-extras"
BINARY="batdiff" # Use one of the scripts for version checking
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME dependencies..."

	# Check if bat is installed
	if ! command -v bat >/dev/null 2>&1 && ! command -v batcat >/dev/null 2>&1; then
		warn "bat or batcat must be installed first"
		# Try to install bat
		if [ "$PACKAGE_MANAGER" = "apt" ]; then
			sudo apt-get update
			sudo apt-get install -y bat || sudo apt-get install -y batcat
		else
			package_install "bat"
		fi

		# Check again
		if ! command -v bat >/dev/null 2>&1 && ! command -v batcat >/dev/null 2>&1; then
			error "bat/batcat installation failed, which is required for bat-extras"
		fi
	fi

	# Install shfmt for script modifications
	case "$PACKAGE_MANAGER" in
	brew)
		brew install shfmt
		;;
	apt)
		# shfmt might not be in the repos, so we'll use snap or go as fallback
		if ! sudo apt-get install -y shfmt 2>/dev/null; then
			if command -v snap >/dev/null 2>&1; then
				sudo snap install shfmt
			elif command -v go >/dev/null 2>&1; then
				GOBIN="$HOME/.local/bin" go install mvdan.cc/sh/v3/cmd/shfmt@latest
				export PATH="$HOME/.local/bin:$PATH"
			else
				warn "Could not install shfmt, which is needed for bat-extras. Installation may not complete correctly."
			fi
		fi
		;;
	dnf)
		sudo dnf install -y shfmt
		;;
	pacman)
		sudo pacman -Sy --noconfirm shfmt
		;;
	*)
		warn "Unknown package manager, trying to install shfmt manually"
		if command -v go >/dev/null 2>&1; then
			GOBIN="$HOME/.local/bin" go install mvdan.cc/sh/v3/cmd/shfmt@latest
			export PATH="$HOME/.local/bin:$PATH"
		else
			warn "Could not install shfmt, which is needed for bat-extras. Installation may not complete correctly."
		fi
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
	(cd "$build_dir" && sudo git config --local --bool core.trustctime false)
	sudo chmod -R g+w "$build_dir"

	# Checkout appropriate version
	if [ "$version_type" = "stable" ]; then
		# Try to get latest tag
		local latest_version=$(git tag -l | grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -n1)

		if [ -n "$latest_version" ]; then
			info "Building version: $latest_version"
			sudo git checkout "$latest_version" || error "Failed to checkout version $latest_version"
		else
			info "No version tags found, using master branch"
			sudo git checkout master || sudo git checkout main || error "Failed to checkout master branch"
		fi
	else
		info "Building from latest HEAD"
		sudo git checkout master || sudo git checkout main || error "Failed to checkout master/main branch"
	fi

	info "Building and installing $TOOL_NAME..."

	# Determine bat binary name on this system (batcat on Debian/Ubuntu)
	local bat_bin="bat"
	if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
		bat_bin="batcat"
		# Tell the build script that bat is actually batcat
		export BAT_COMMAND=batcat
	fi

	# Build with platform-specific options
	if [ "$OS_TYPE" = "macos" ]; then
		# On macOS, use the standard installation
		sudo -E ./build.sh --prefix="$BASE_DIR" --install || error "Failed to build and install"
	else
		# On Linux, handle Debian/Ubuntu differently with batcat
		sudo -E env BAT_COMMAND="$bat_bin" ./build.sh --prefix="$BASE_DIR" --install || error "Failed to build and install"
	fi

	# Create symlinks with the right name
	if [ "$bat_bin" = "batcat" ]; then
		# For batcat, adjust the symlinks so scripts work properly
		for script in "$BASE_DIR/bin/bat"*; do
			if [[ "$script" == "$BASE_DIR/bin/batcat"* ]]; then
				continue # Skip if it already starts with batcat
			fi

			base_name=$(basename "$script")
			# Create catcat version of the script if needed
			if [[ "$base_name" != "bat" ]]; then
				target_name="${base_name/bat/batcat}"
				create_managed_symlink "$script" "$BASE_DIR/bin/$target_name"
			fi
		done
	fi
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting installation of $TOOL_NAME..."

	# Install dependencies first
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
