#!/usr/bin/env bash

###############################################################################
# Common Functions Library
#
# Purpose:
# Provides shared functionality for the development tools management system.
# This script handles:
# - Directory and permission management
# - Version detection and comparison
# - Tool configuration parsing
# - Common installation procedures
# - Post-installation tasks
#
# Environment:
# All operations assume root:staff ownership and 775/664 permissions
# All paths are system-wide under /opt/local or /usr/local
###############################################################################

set -euo pipefail

# Status message functions
info() { echo "[INFO] $1" >&2; }
warn() { echo "[WARN] $1" >&2; }
error() {
	echo "[ERROR] $1"
	exit 1
}

###############################################################################
# Base Directory Management
###############################################################################

# Get the base installation directory
# Will be either /opt/local or /usr/local
get_base_dir() {
	if [ -d "/opt/local" ]; then
		echo "/opt/local"
	elif [ -d "/usr/local" ]; then
		echo "/usr/local"
	else
		error "No valid installation directory found"
	fi
}

# Set up global variables for common paths
BASE_DIR="$(get_base_dir)"
CACHE_DIR="$BASE_DIR/share/dev/cache"
CONFIG_DIR="$BASE_DIR/etc/dev"
TOOLS_CONF="$CONFIG_DIR/tools.conf"

###############################################################################
# Permission Management
###############################################################################

# Create or update directory with correct permissions
# Args:
#   $1: Directory path
#   $2: Optional permissions (default: 775)
#   $3: Optional recursive flag (default: false)
ensure_dir_permissions() {
	local dir="$1"
	local perms="${2:-775}"
	local recursive="${3:-false}"

	sudo mkdir -p "$dir"
	if [ "$recursive" = "true" ]; then
		sudo chmod -R "$perms" "$dir"
		sudo chown -R root:staff "$dir"
	else
		sudo chmod "$perms" "$dir"
		sudo chown root:staff "$dir"
	fi
}

# Create a managed symlink
# Args:
#   $1: Source path
#   $2: Target path in bin directory
create_managed_symlink() {
	local src="$1"
	local target="$2"

	sudo ln -sf "$src" "$target"
	sudo chown -h root:staff "$target"
}

###############################################################################
# Version Management
###############################################################################

# Compare two version strings
# Returns: 0 if version1 > version2
#         1 if version1 < version2
#         2 if version1 = version2
compare_versions() {
	if [[ "$1" == "$2" ]]; then
		return 2
	fi
	local IFS=.
	local i ver1=($1) ver2=($2)
	# Fill empty positions in ver1 with zeros
	for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
		ver1[i]=0
	done
	for ((i = 0; i < ${#ver1[@]}; i++)); do
		# Fill empty positions in ver2 with zeros
		if [[ -z ${ver2[i]} ]]; then
			ver2[i]=0
		fi
		if ((10#${ver1[i]} > 10#${ver2[i]})); then
			return 0
		fi
		if ((10#${ver1[i]} < 10#${ver2[i]})); then
			return 1
		fi
	done
	return 2
}

###############################################################################
# Tool Configuration Management
###############################################################################

# Parse tool configuration from tools.conf
# Args:
#   $1: Tool name
# Sets global variables:
#   TOOL_VERSION_TYPE: stable|head|managed|none
parse_tool_config() {
	local tool_name="$1"
	local config_line

	# Read tool configuration
	if [ -f "$TOOLS_CONF" ]; then
		config_line=$(grep "^$tool_name=" "$TOOLS_CONF" | cut -d= -f2-)
	fi

	if [ -z "${config_line:-}" ]; then
		TOOL_VERSION_TYPE="stable"
		return
	fi

	# Parse version type - just take the first part before any comma
	TOOL_VERSION_TYPE=$(echo "$config_line" | cut -d, -f1 | tr -d ' ')
}

###############################################################################
# Repository Management
###############################################################################

# Setup tool repository in cache
# Args:
#   $1: Tool name
#   $2: Repository URL
setup_tool_repo() {
	local tool_name="$1"
	local repo_url="$2"
	local cache_dir="$CACHE_DIR/$tool_name"

	ensure_dir_permissions "$cache_dir"

	if [ ! -d "$cache_dir/.git" ]; then
		info "Cloning $tool_name repository..."
		sudo -u root git clone "$repo_url" "$cache_dir" || error "Failed to clone repository"
	else
		info "Updating $tool_name repository..."
		(cd "$cache_dir" && sudo -u root git fetch) || error "Failed to update repository"
	fi

	echo "$cache_dir"
}

###############################################################################
# Build Management
###############################################################################

# Configure build flags
configure_build_flags() {
	local cpu_count=$(nproc)
	# Use one less than available cores to prevent system lockup
	export MAKE_FLAGS="-j$((cpu_count - 1))"
}

###############################################################################
# Post-Installation Management
###############################################################################

# Execute post-installation commands if specified
# Args:
#   $1: Tool name
execute_post_install() {
	local tool_name="$1"

	if [ -n "$TOOL_POST_COMMAND" ]; then
		info "Executing post-installation commands for $tool_name"
		eval "$TOOL_POST_COMMAND" || warn "Post-installation command failed"
	fi
}

###############################################################################
# Main Installation Function
###############################################################################

# Install or update a tool
# Args:
#   $1: Tool name
#   $2: Binary name
#   $3: Version command
#   $4: Repository directory
#   $5: Build function name
install_or_update_tool() {
	local tool_name="$1"
	local binary="$2"
	local version_cmd="$3"
	local repo_dir="$4"
	local build_func="$5"

	# Parse tool configuration for version type only
	parse_tool_config "$tool_name"

	case "$TOOL_VERSION_TYPE" in
	none)
		info "Skipping $tool_name as configured"
		return 0
		;;
	managed)
		info "Installing $tool_name via package manager"
		package_install "$tool_name"
		;;
	stable | head)
		if [ -x "$BASE_DIR/bin/$binary" ]; then
			info "$tool_name is already installed, checking for updates..."
		fi

		# Build from source
		"$build_func" "$repo_dir" "$TOOL_VERSION_TYPE"
		;;
	*)
		error "Invalid version type: $TOOL_VERSION_TYPE"
		;;
	esac
}
