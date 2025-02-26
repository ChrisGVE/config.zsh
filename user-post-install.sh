#!/usr/bin/env bash

###############################################################################
# User Post-Installation Script
#
# Purpose:
# This script handles user-specific configurations after system-wide tool
# installations have been completed. It:
# - Clones user configuration repositories
# - Runs post-installation commands for each tool
# - Sets up user-specific caches and preferences
# - Installs and configures ZSH plugins & themes
#
# This script should be run without sudo as the current user.
###############################################################################

set -euo pipefail

# Status message functions
info() { echo "[INFO] User Setup: $1" >&2; }
warn() { echo "[WARN] User Setup: $1" >&2; }
error() {
	echo "[ERROR] User Setup: $1"
	exit 1
}

# Detect platform
detect_platform() {
	case "$(uname -s)" in
	Darwin*)
		export OS_TYPE="macos"
		if command -v brew >/dev/null 2>&1; then
			export HOMEBREW_PREFIX="$(brew --prefix)"
		fi
		;;
	Linux*)
		export OS_TYPE="linux"
		# Detect Raspberry Pi
		if [[ -f /sys/firmware/devicetree/base/model ]] && grep -q "Raspberry Pi" /sys/firmware/devicetree/base/model; then
			export OS_TYPE="raspberrypi"
		elif [[ -f /proc/cpuinfo ]] && grep -q "^Model.*:.*Raspberry" /proc/cpuinfo; then
			export OS_TYPE="raspberrypi"
		fi
		;;
	*)
		export OS_TYPE="unknown"
		warn "Unsupported operating system: $(uname -s)"
		;;
	esac

	info "Detected platform: $OS_TYPE"
}

# Determine base installation directory
get_base_dir() {
	if [ -d "/opt/local" ]; then
		echo "/opt/local"
	elif [ -d "/usr/local" ]; then
		echo "/usr/local"
	else
		error "No valid installation directory found"
	fi
}

BASE_DIR=$(get_base_dir)
CONFIG_FILE="$BASE_DIR/etc/dev/tools.conf"

# Verify the user is not running as root
if [ "$(id -u)" -eq 0 ]; then
	error "This script should not be run as root or with sudo. Please run as a normal user."
fi

###############################################################################
# Environment Setup
###############################################################################

# Setup XDG directories
setup_xdg_dirs() {
	info "Setting up XDG directories..."

	# Create XDG base directories
	mkdir -p "$HOME/.config"
	mkdir -p "$HOME/.local/share"
	mkdir -p "$HOME/.local/runtime"
	mkdir -p "$HOME/.local/state"
	mkdir -p "$HOME/.cache"
	mkdir -p "$HOME/.local/bin"

	# Ensure proper permissions
	chmod 700 "$HOME/.config"
	chmod 700 "$HOME/.local"
	chmod 700 "$HOME/.cache"

	# Add .local/bin to PATH if not already there
	if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
		export PATH="$HOME/.local/bin:$PATH"
	fi
}

###############################################################################
# ZSH Plugin Installation
###############################################################################

# Install Oh My Zsh
install_ohmyzsh() {
	info "Setting up Oh My Zsh..."
	local oh_my_zsh_dir="$HOME/.config/zsh/ohmyzsh"

	# Create ZSH config directory if it doesn't exist
	mkdir -p "$HOME/.config/zsh"

	if [ -d "$oh_my_zsh_dir" ]; then
		info "Oh My Zsh is already installed, updating..."
		(cd "$oh_my_zsh_dir" && git pull) || warn "Failed to update Oh My Zsh"
	else
		info "Installing Oh My Zsh..."
		# Clone with proper path
		git clone https://github.com/ohmyzsh/ohmyzsh.git "$oh_my_zsh_dir" || {
			warn "Failed to clone Oh My Zsh repository"
			return 1
		}
	fi

	# Ensure custom directory exists
	mkdir -p "$HOME/.config/zsh/custom/plugins"
	mkdir -p "$HOME/.config/zsh/custom/themes"

	return 0
}

# Install Oh My Posh
install_oh_my_posh() {
	info "Setting up Oh My Posh..."

	# Check if Oh My Posh is already installed
	if command -v oh-my-posh >/dev/null 2>&1; then
		info "Oh My Posh is already installed, upgrading..."

		case "$OS_TYPE" in
		macos)
			if command -v brew >/dev/null 2>&1; then
				brew upgrade oh-my-posh || warn "Failed to upgrade Oh My Posh"
			else
				warn "Homebrew not found, cannot upgrade Oh My Posh"
			fi
			;;
		linux | raspberrypi)
			curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin" || warn "Failed to upgrade Oh My Posh"
			;;
		esac
	else
		info "Installing Oh My Posh..."

		case "$OS_TYPE" in
		macos)
			if command -v brew >/dev/null 2>&1; then
				brew install jandedobbeleer/oh-my-posh/oh-my-posh || warn "Failed to install Oh My Posh"
			else
				warn "Homebrew not found, using alternate installation method"
				curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
			fi
			;;
		linux | raspberrypi)
			curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin" || warn "Failed to install Oh My Posh"
			;;
		esac
	fi

	# Create configuration directory
	mkdir -p "$HOME/.config/zsh/oh-my-posh"

	# Download default theme if it doesn't exist
	if [ ! -f "$HOME/.config/zsh/oh-my-posh/config.yml" ]; then
		# Use catppuccin mocha theme by default
		curl -s -o "$HOME/.config/zsh/oh-my-posh/config.yml" \
			"https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/catppuccin_mocha.omp.json" ||
			warn "Failed to download default theme"
	fi

	return 0
}

# Install additional ZSH plugins
install_zsh_plugins() {
	info "Setting up additional ZSH plugins..."
	local plugins_dir="$HOME/.config/zsh/plugins"
	mkdir -p "$plugins_dir"

	# ZSH Autosuggestions
	if [ ! -d "$plugins_dir/zsh-autosuggestions" ]; then
		git clone https://github.com/zsh-users/zsh-autosuggestions.git "$plugins_dir/zsh-autosuggestions" || {
			warn "Failed to clone zsh-autosuggestions repository"
		}
	else
		(cd "$plugins_dir/zsh-autosuggestions" && git pull) || warn "Failed to update zsh-autosuggestions"
	fi

	# Fast Syntax Highlighting
	if [ ! -d "$plugins_dir/fast-syntax-highlighting" ]; then
		git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$plugins_dir/fast-syntax-highlighting" || {
			warn "Failed to clone fast-syntax-highlighting repository"
		}
	else
		(cd "$plugins_dir/fast-syntax-highlighting" && git pull) || warn "Failed to update fast-syntax-highlighting"
	fi

	# ZSH Vi Mode
	if [ ! -d "$plugins_dir/zsh-vi-mode" ]; then
		git clone https://github.com/jeffreytse/zsh-vi-mode.git "$plugins_dir/zsh-vi-mode" || {
			warn "Failed to clone zsh-vi-mode repository"
		}
	else
		(cd "$plugins_dir/zsh-vi-mode" && git pull) || warn "Failed to update zsh-vi-mode"
	fi

	# Create plugin cache directory to avoid theme file system checks
	mkdir -p "$HOME/.cache/zsh"

	return 0
}

# Install catppuccin theme files
install_catppuccin_themes() {
	info "Setting up Catppuccin themes..."
	local themes_dir="$HOME/.config/zsh/themes"
	mkdir -p "$themes_dir"

	# Catppuccin for ZSH
	if [ ! -d "$themes_dir/catppuccin-zsh-syntax-highlighting" ]; then
		git clone https://github.com/catppuccin/zsh-syntax-highlighting.git "$themes_dir/catppuccin-zsh-syntax-highlighting" || {
			warn "Failed to clone catppuccin zsh-syntax-highlighting repository"
		}
	else
		(cd "$themes_dir/catppuccin-zsh-syntax-highlighting" && git pull) || warn "Failed to update catppuccin zsh-syntax-highlighting"
	fi

	# Catppuccin for FZF
	if [ ! -d "$themes_dir/catppuccin-fzf" ]; then
		git clone https://github.com/catppuccin/fzf.git "$themes_dir/catppuccin-fzf" || {
			warn "Failed to clone catppuccin fzf repository"
		}
	else
		(cd "$themes_dir/catppuccin-fzf" && git pull) || warn "Failed to update catppuccin fzf"
	fi

	# Catppuccin for Bat
	mkdir -p "$HOME/.config/bat/themes"
	if [ ! -d "$themes_dir/catppuccin-bat" ]; then
		git clone https://github.com/catppuccin/bat.git "$themes_dir/catppuccin-bat" || {
			warn "Failed to clone catppuccin bat repository"
		}
		# Copy the theme files to bat config
		if [ -d "$themes_dir/catppuccin-bat" ]; then
			cp "$themes_dir/catppuccin-bat/themes/"*.tmTheme "$HOME/.config/bat/themes/" || warn "Failed to copy bat themes"
		fi
	else
		(cd "$themes_dir/catppuccin-bat" && git pull) || warn "Failed to update catppuccin bat"
		# Update theme files
		cp "$themes_dir/catppuccin-bat/themes/"*.tmTheme "$HOME/.config/bat/themes/" || warn "Failed to copy bat themes"
	fi

	return 0
}

###############################################################################
# Configuration Repository Management
###############################################################################

clone_tool_config() {
	local tool_name="$1"
	local config_repo="https://github.com/ChrisGVE/config.${tool_name}.git"
	local config_dir="$HOME/.config/${tool_name}"

	info "Checking configuration for $tool_name..."

	# Verify the repository exists
	if ! curl --output /dev/null --silent --head --fail "$config_repo"; then
		info "No configuration found for $tool_name"
		return 0
	fi

	# Handle existing configuration
	if [ -d "$config_dir" ]; then
		info "Configuration already exists for $tool_name, creating backup..."
		mv "$config_dir" "${config_dir}.backup.$(date +%Y%m%d%H%M%S)"
	fi

	# Clone the configuration
	info "Cloning configuration for $tool_name..."
	git clone "$config_repo" "$config_dir" || {
		warn "Failed to clone configuration for $tool_name"
		return 1
	}

	info "Configuration installed for $tool_name"
	return 0
}

###############################################################################
# Post-Installation Command Execution
###############################################################################

execute_post_command() {
	local tool_name="$1"

	# Find post command in tools.conf
	if [ ! -f "$CONFIG_FILE" ]; then
		warn "Configuration file not found: $CONFIG_FILE"
		return 1
	fi

	local config_line=$(grep "^$tool_name=" "$CONFIG_FILE" | cut -d= -f2-)
	if [ -z "$config_line" ]; then
		return 0
	fi

	# Check for post command
	if echo "$config_line" | grep -q "post="; then
		local post_command=$(echo "$config_line" | grep -o 'post="[^"]*"' | cut -d'"' -f2)

		if [ -n "$post_command" ]; then
			info "Executing post-installation command for $tool_name..."
			eval "$post_command"
			return $?
		fi
	fi

	return 0
}

###############################################################################
# Tool Configuration Processing
###############################################################################

process_tool() {
	local tool_name="$1"
	info "Processing user setup for $tool_name..."

	# Skip if the tool is not installed
	if ! command -v "$tool_name" >/dev/null 2>&1; then
		info "$tool_name is not installed, skipping user setup"
		return 0
	fi

	# Check if configuration is needed
	local needs_config=0
	if grep -q "^$tool_name=.*config" "$CONFIG_FILE" 2>/dev/null; then
		needs_config=1
	fi

	# Clone configuration if needed
	if [ "$needs_config" -eq 1 ]; then
		clone_tool_config "$tool_name"
	fi

	# Execute post-installation command
	execute_post_command "$tool_name"
}

###############################################################################
# ZSH Configuration Setup
###############################################################################

setup_zsh_config() {
	info "Setting up ZSH configuration symlinks..."

	# Backup existing files if they're not symlinks
	for file in "$HOME/.zshenv" "$HOME/.zshrc"; do
		if [[ -f "$file" && ! -L "$file" ]]; then
			mv "$file" "$file.backup.$(date +%Y%m%d%H%M%S)"
			info "Backed up existing $file"
		fi
	done

	# Create symlinks
	ln -sf "$HOME/.config/zsh/zshenv" "$HOME/.zshenv"
	ln -sf "$HOME/.config/zsh/zshrc" "$HOME/.zshrc"

	info "ZSH configuration symlinks created"
}

###############################################################################
# Main Process
###############################################################################

main() {
	info "Starting user-specific post-installation setup..."

	# Detect platform
	detect_platform

	# Setup XDG directories
	setup_xdg_dirs

	# Install ZSH plugins and themes
	install_ohmyzsh
	install_oh_my_posh
	install_zsh_plugins
	install_catppuccin_themes

	# Setup ZSH configuration first
	setup_zsh_config

	# Process each tool from the configuration file
	if [ -f "$CONFIG_FILE" ]; then
		while IFS= read -r line || [ -n "$line" ]; do
			if [[ "$line" =~ ^([a-zA-Z0-9_-]+)= ]]; then
				tool_name="${BASH_REMATCH[1]}"
				process_tool "$tool_name"
			fi
		done <"$CONFIG_FILE"
	else
		warn "Configuration file not found: $CONFIG_FILE"
	fi

	info "User-specific post-installation setup complete"
}

# Execute main process
main "$@"
