#!/usr/bin/env bash

###############################################################################
# Delta Installation Script (Debug Version)
#
# Purpose:
# Installs or updates delta (https://github.com/dandavison/delta)
# A syntax-highlighting pager for git, diff, and grep output
###############################################################################

set -o pipefail

# Source common functions
echo "DEBUG: About to source common functions"
source "$(dirname "$0")/../common.sh"
echo "DEBUG: Completed sourcing common functions"

# Tool-specific configuration
TOOL_NAME="delta"
REPO_URL="https://github.com/dandavison/delta"
BINARY="delta"
VERSION_CMD="--version"

# Enhanced debug function
debug() { echo "[DEBUG] $1" >&2; }

# Add timeout function for commands that might hang
run_with_timeout() {
	local timeout=$1
	shift

	# Create named pipe for communication
	local pipe=$(mktemp -u)
	mkfifo "$pipe"

	# Start command in background
	(
		"$@"
		echo $? >"$pipe"
	) &
	local pid=$!

	# Wait for command to finish or timeout
	local result
	if read -t "$timeout" result <"$pipe"; then
		rm "$pipe"
		return $result
	else
		debug "Command timed out after $timeout seconds: $*"
		kill -9 $pid 2>/dev/null || true
		wait $pid 2>/dev/null || true
		rm "$pipe"
		return 124 # Standard timeout exit code
	fi
}

###############################################################################
# Installation Functions
###############################################################################

parse_config_safe() {
	debug "Starting parse_tool_config for $TOOL_NAME"

	# Default values in case parsing fails
	TOOL_VERSION_TYPE="stable"
	TOOL_CONFIG="false"
	TOOL_POST_COMMAND=""

	# Try to parse with timeout
	local config_line=""

	if [ -f "$TOOLS_CONF" ]; then
		debug "tools.conf exists at $TOOLS_CONF"
		# Use grep directly with a timeout
		config_line=$(timeout 10 grep "^$TOOL_NAME=" "$TOOLS_CONF" 2>/dev/null | sed 's/#.*$//' | cut -d= -f2- || echo "")
		debug "Config line from tools.conf: '$config_line'"
	else
		debug "tools.conf not found at expected location: $TOOLS_CONF"
	fi

	if [ -n "${config_line}" ]; then
		# Parse version type - just take the first part before any comma
		TOOL_VERSION_TYPE=$(echo "$config_line" | cut -d, -f1 | tr -d ' ')
		debug "Parsed version type: $TOOL_VERSION_TYPE"

		# Parse config flag if present
		if echo "$config_line" | grep -q "config"; then
			TOOL_CONFIG="true"
			debug "Config flag is set to true"
		fi

		# Parse post command if present
		if echo "$config_line" | grep -q "post="; then
			TOOL_POST_COMMAND=$(echo "$config_line" | grep -o 'post="[^"]*"' | cut -d'"' -f2)
			debug "Post command: $TOOL_POST_COMMAND"
		fi
	else
		debug "No configuration found, using defaults"
	fi

	debug "Final configuration: type=$TOOL_VERSION_TYPE, config=$TOOL_CONFIG, post_cmd_length=${#TOOL_POST_COMMAND}"
}

install_deps() {
	debug "Starting install_deps"
	info "Installing $TOOL_NAME build dependencies..."

	case "$PACKAGE_MANAGER" in
	brew)
		brew install cmake pkg-config
		;;
	apt)
		debug "Using apt to install dependencies"
		run_with_timeout 120 sudo apt-get update
		debug "apt-get update completed"
		run_with_timeout 300 sudo apt-get install -y cmake pkg-config libssl-dev
		debug "apt-get install completed"
		;;
	dnf)
		run_with_timeout 120 sudo dnf install -y cmake pkg-config openssl-devel
		;;
	pacman)
		run_with_timeout 120 sudo pacman -Sy --noconfirm cmake pkg-config openssl
		;;
	*)
		warn "Unknown package manager: $PACKAGE_MANAGER, trying to install dependencies manually"
		run_with_timeout 120 package_install "cmake"
		run_with_timeout 120 package_install "pkg-config"
		run_with_timeout 120 package_install "libssl-dev"
		;;
	esac

	debug "Dependencies installed, checking for Rust"

	# Check if Rust is available without calling ensure_rust_available
	if ! command -v cargo >/dev/null 2>&1; then
		debug "Cargo not found in PATH"
		# Check for Rust in our toolchain location
		local rust_cargo="$BASE_DIR/share/dev/toolchains/rust/cargo/bin/cargo"

		if [ -f "$rust_cargo" ]; then
			debug "Found Cargo at $rust_cargo, adding to PATH"
			export PATH="$BASE_DIR/share/dev/toolchains/rust/cargo/bin:$PATH"
			export RUSTUP_HOME="$BASE_DIR/share/dev/toolchains/rust/rustup"
			export CARGO_HOME="$BASE_DIR/share/dev/toolchains/rust/cargo"
		else
			debug "Rust not found in expected location, will need to install it"
		fi
	else
		debug "Cargo is available in PATH: $(which cargo)"
	fi
}

###############################################################################
# Main Installation Process (Simplified for Debugging)
###############################################################################

main() {
	debug "Starting main function"

	echo "DEBUG STEP 1: Parse tool configuration"
	parse_config_safe
	info "Configured $TOOL_NAME version type: $TOOL_VERSION_TYPE"

	echo "DEBUG STEP 2: Check current installation"
	if command -v delta >/dev/null 2>&1; then
		debug "delta command is available: $(which delta)"
		current_version=$(delta --version 2>&1 | head -n1)
		info "Current delta version: $current_version"
	else
		debug "delta command is not available"
		info "Delta is not currently installed"
	fi

	echo "DEBUG STEP 3: Install via package manager"
	debug "Installing via apt"
	run_with_timeout 300 sudo apt-get update
	debug "apt-get update completed"
	run_with_timeout 300 sudo apt-get install -y git-delta
	debug "apt-get install git-delta completed"

	echo "DEBUG STEP 4: Check if installation succeeded"
	if command -v delta >/dev/null 2>&1; then
		info "delta command now available: $(which delta)"
		current_version=$(delta --version 2>&1 | head -n1)
		info "Installed delta version: $current_version"
	elif command -v git-delta >/dev/null 2>&1; then
		info "git-delta command available: $(which git-delta)"
		sudo ln -sf "$(which git-delta)" "$BASE_DIR/bin/delta"
		info "Created symlink from git-delta to delta"
	else
		warn "delta command still not available after installation"
	fi

	echo "DEBUG STEP 5: Configure git to use delta"
	if command -v git >/dev/null 2>&1; then
		debug "git command is available: $(which git)"
		info "Configuring git to use delta..."
		git config --global core.pager delta
		git config --global interactive.diffFilter "delta --color-only"
		git config --global delta.navigate true
		git config --global merge.conflictStyle zdiff3
	else
		debug "git command is not available"
		warn "Git not found, skipping configuration"
	fi

	info "Delta installation and configuration completed"
}

# Run main with full debugging
echo "Starting delta.sh with debugging enabled"
main
echo "delta.sh completed execution"
