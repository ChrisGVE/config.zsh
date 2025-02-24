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

# Determine base installation directory
BASE_DIR=$([ -d "/opt/local" ] && echo "/opt/local" || echo "/usr/local")
CONFIG_FILE="$BASE_DIR/etc/dev/tools.conf"

# Verify the user is not running as root
if [ "$(id -u)" -eq 0 ]; then
	error "This script should not be run as root or with sudo. Please run as a normal user."
fi

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
