#!/usr/bin/env bash

###############################################################################
# Lolcat Installation Script
#
# Purpose:
# Installs or updates lolcat (https://github.com/busyloop/lolcat)
# A command that displays text with rainbow colors
#
# Dependencies:
# - Ruby installed by toolchain or package manager
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="lolcat"
BINARY="lolcat"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_via_package_manager() {
	info "Installing $TOOL_NAME via package manager..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install lolcat
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y lolcat
		;;
	dnf)
		sudo dnf install -y lolcat
		;;
	pacman)
		sudo pacman -Sy --noconfirm lolcat
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, cannot install via package manager"
		return 1
		;;
	esac

	# Check if installation succeeded
	if command -v lolcat >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

install_via_gem() {
	info "Installing $TOOL_NAME via Ruby gem..."

	# Ensure Ruby is installed
	if ! command -v ruby >/dev/null 2>&1; then
		warn "Ruby not found, cannot install via gem"
		return 1
	fi

	if ! command -v gem >/dev/null 2>&1; then
		warn "Gem command not found, cannot install Ruby gems"
		return 1
	fi

	# Check if the user can install gems without sudo
	if gem environment >/dev/null 2>&1; then
		# Try installing for the current user first
		gem install lolcat --user-install || {
			warn "Failed to install for current user, trying with sudo"
			sudo gem install lolcat
		}
	else
		# Fall back to sudo installation
		sudo gem install lolcat
	fi

	# Check if installation succeeded
	if command -v lolcat >/dev/null 2>&1; then
		return 0
	fi

	# Check if it's in the user's gem bin directory
	local gem_bin_dir=$(ruby -e 'puts Gem.user_dir' 2>/dev/null)/bin
	if [ -f "$gem_bin_dir/lolcat" ]; then
		# Create symlink to make it available in PATH
		mkdir -p "$HOME/.local/bin"
		ln -sf "$gem_bin_dir/lolcat" "$HOME/.local/bin/lolcat"

		# Also create a system-wide symlink
		create_managed_symlink "$gem_bin_dir/lolcat" "$BASE_DIR/bin/lolcat"

		# Add to PATH for this session
		export PATH="$HOME/.local/bin:$PATH"

		return 0
	fi

	return 1
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting installation of $TOOL_NAME..."

	# Parse tool configuration
	parse_tool_config "$TOOL_NAME"

	# Try package manager first
	if install_via_package_manager; then
		info "$TOOL_NAME successfully installed via package manager"
		return 0
	fi

	# Try gem installation
	if install_via_gem; then
		info "$TOOL_NAME successfully installed via gem"
		return 0
	fi

	# If we get here, both installation methods failed
	error "Failed to install $TOOL_NAME using available methods"
}

# Run the main installation
main
