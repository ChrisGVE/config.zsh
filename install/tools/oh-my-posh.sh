#!/usr/bin/env bash

###############################################################################
# Oh My Posh Installation Script
#
# Purpose:
# Installs or updates Oh My Posh (https://ohmyposh.dev/)
# A prompt theme engine for any shell
#
# Features:
# - Cross-platform installation (macOS, Linux, Raspberry Pi)
# - Configuration template setup
# - Default theme installation
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="oh-my-posh"
BINARY="oh-my-posh"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

# Platform-specific installation method
install_oh_my_posh() {
	local installation_dir="$BASE_DIR/share/oh-my-posh"
	local themes_dir="$installation_dir/themes"

	# Create installation directory
	sudo mkdir -p "$installation_dir"
	sudo mkdir -p "$themes_dir"
	sudo chown root:$ADMIN_GROUP "$installation_dir"
	sudo chown root:$ADMIN_GROUP "$themes_dir"
	sudo chmod 775 "$installation_dir"
	sudo chmod 775 "$themes_dir"

	# Determine platform-specific installation
	case "$OS_TYPE" in
	macos)
		if command -v brew >/dev/null 2>&1; then
			info "Installing Oh My Posh via Homebrew on macOS"
			if ! brew list jandedobbeleer/oh-my-posh/oh-my-posh &>/dev/null; then
				brew install jandedobbeleer/oh-my-posh/oh-my-posh
			else
				brew upgrade jandedobbeleer/oh-my-posh/oh-my-posh || true
			fi

			# Create symlink to Homebrew's oh-my-posh
			if [ -f "$HOMEBREW_PREFIX/bin/oh-my-posh" ]; then
				create_managed_symlink "$HOMEBREW_PREFIX/bin/oh-my-posh" "$BASE_DIR/bin/oh-my-posh"
				return 0
			else
				return 1
			fi
		else
			info "Homebrew not found, installing Oh My Posh directly"
			install_direct
		fi
		;;
	linux | raspberrypi)
		install_direct
		;;
	*)
		error "Unsupported platform: $OS_TYPE"
		;;
	esac
}

# Direct installation method using the official install script
install_direct() {
	local installation_dir="$BASE_DIR/share/oh-my-posh"
	local themes_dir="$installation_dir/themes"
	local tmp_dir=$(mktemp -d)

	info "Installing Oh My Posh directly from official source..."

	# Create a custom install script that directs themes to our desired location
	cat >"$tmp_dir/install.sh" <<'EOF'
#!/bin/bash
set -e

THEME_LOCATION="$1/themes"
INSTALL_DIR="$1"

# Use a more compatible curl command for Debian/Raspberry Pi
download() {
    curl -fsSL "$1" -o "$2"
}

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)  ARCH="amd64" ;;
    armv7l)  ARCH="arm" ;;
    aarch64) ARCH="arm64" ;;
    *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)  OS="linux" ;;
    Darwin*) OS="darwin" ;;
    *)       echo "Unsupported OS: $OS"; exit 1 ;;
esac

# Download the binary
echo "Installing oh-my-posh for ${OS}-${ARCH} in ${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
mkdir -p "${THEME_LOCATION}"
download "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-${OS}-${ARCH}" "${INSTALL_DIR}/oh-my-posh"
chmod +x "${INSTALL_DIR}/oh-my-posh"

# Download themes
echo "Installing oh-my-posh themes in ${THEME_LOCATION}"
download "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip" "${INSTALL_DIR}/themes.zip"
unzip -o "${INSTALL_DIR}/themes.zip" -d "${THEME_LOCATION}"
rm "${INSTALL_DIR}/themes.zip"

echo "Installation complete."
echo "You can now add oh-my-posh to your shell configuration."
EOF

	# Make the script executable
	chmod +x "$tmp_dir/install.sh"

	# Run the custom install script with sudo to install to system location
	sudo "$tmp_dir/install.sh" "$installation_dir"

	# Create symlink if installation succeeded
	if [ -f "$installation_dir/oh-my-posh" ]; then
		create_managed_symlink "$installation_dir/oh-my-posh" "$BASE_DIR/bin/oh-my-posh"
		rm -rf "$tmp_dir"
		return 0
	else
		rm -rf "$tmp_dir"
		return 1
	fi
}

# Setup themes for user
setup_user_themes() {
	local system_themes_dir="$BASE_DIR/share/oh-my-posh/themes"
	local user_themes_dir="$HOME/.config/zsh/oh-my-posh"

	# Create user themes directory
	mkdir -p "$user_themes_dir"

	# Copy a default theme to user config only if needed and system themes exist
	if [ ! -f "$user_themes_dir/config.yml" ] && [ -d "$system_themes_dir" ]; then
		if [ -f "$system_themes_dir/catppuccin_mocha.omp.json" ]; then
			cp "$system_themes_dir/catppuccin_mocha.omp.json" "$user_themes_dir/config.yml"
			info "Default theme copied to $user_themes_dir/config.yml"
		elif [ -f "$system_themes_dir/atomic.omp.json" ]; then
			cp "$system_themes_dir/atomic.omp.json" "$user_themes_dir/config.yml"
			info "Default theme copied to $user_themes_dir/config.yml"
		elif [ "$(ls -A "$system_themes_dir")" ]; then
			# If any themes exist, copy the first one found
			first_theme=$(ls -1 "$system_themes_dir"/*.json | head -1)
			if [ -n "$first_theme" ]; then
				cp "$first_theme" "$user_themes_dir/config.yml"
				info "Theme $(basename "$first_theme") copied to $user_themes_dir/config.yml"
			fi
		else
			info "No themes found in $system_themes_dir, skipping default theme setup"
		fi
	elif [ -f "$user_themes_dir/config.yml" ]; then
		info "User theme already exists at $user_themes_dir/config.yml"
	fi
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting installation of $TOOL_NAME..."

	# Parse tool configuration
	parse_tool_config "$TOOL_NAME"

	# Install Oh My Posh
	if install_oh_my_posh; then
		# Verify installation
		if command -v oh-my-posh >/dev/null 2>&1; then
			local version=$(oh-my-posh --version 2>/dev/null | head -n1)
			info "Oh My Posh installed successfully - version: $version"

			# Setup user themes
			setup_user_themes
		else
			warn "Oh My Posh binary not found in PATH after installation"
		fi
	else
		error "Failed to install Oh My Posh"
	fi

	info "$TOOL_NAME installation completed successfully"
}

# Run the main installation
main
