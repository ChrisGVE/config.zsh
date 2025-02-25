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
# Package Manager Operations
###############################################################################

# Install a package using the appropriate package manager
package_install() {
	local package_name="$1"
	info "Installing package: $package_name"

	# Detect package manager if not already set
	if [ -z "${PACKAGE_MANAGER:-}" ]; then
		if [ -f /etc/os-release ]; then
			. /etc/os-release
			if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ] || [ "$ID" = "raspbian" ]; then
				PACKAGE_MANAGER="apt"
			elif [ "$ID" = "fedora" ] || [ "$ID" = "rhel" ] || [ "$ID" = "centos" ]; then
				PACKAGE_MANAGER="dnf"
			elif [ "$ID" = "arch" ] || [ "$ID" = "manjaro" ]; then
				PACKAGE_MANAGER="pacman"
			elif command -v apt >/dev/null 2>&1; then
				PACKAGE_MANAGER="apt"
			elif command -v dnf >/dev/null 2>&1; then
				PACKAGE_MANAGER="dnf"
			elif command -v pacman >/dev/null 2>&1; then
				PACKAGE_MANAGER="pacman"
			else
				error "Unsupported distribution for package installation"
			fi
		else
			error "Cannot determine distribution type for package installation"
		fi
	fi

	case "$PACKAGE_MANAGER" in
	apt)
		sudo apt install -y "$package_name"
		;;
	dnf)
		sudo dnf install -y "$package_name"
		;;
	pacman)
		sudo pacman -S --noconfirm "$package_name"
		;;
	*)
		error "Unsupported package manager: $PACKAGE_MANAGER"
		;;
	esac
}

# Get the current package manager
get_package_manager() {
	echo "${PACKAGE_MANAGER:-unknown}"
}

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
	local config_line=""

	# Read tool configuration
	if [ -f "$TOOLS_CONF" ]; then
		# Extract only the configuration part, ignoring comments
		config_line=$(grep "^$tool_name=" "$TOOLS_CONF" | sed 's/#.*$//' | cut -d= -f2-)
	else
		warn "tools.conf not found at $TOOLS_CONF"
	fi

	if [ -z "${config_line:-}" ]; then
		TOOL_VERSION_TYPE="stable"
		return
	fi

	# Parse version type - just take the first part before any comma
	TOOL_VERSION_TYPE=$(echo "$config_line" | cut -d, -f1 | tr -d ' ')

	# Parse config flag if present
	if echo "$config_line" | grep -q "config"; then
		TOOL_CONFIG="true"
	else
		TOOL_CONFIG="false"
	fi

	# Parse post command if present
	TOOL_POST_COMMAND=""
	if echo "$config_line" | grep -q "post="; then
		TOOL_POST_COMMAND=$(echo "$config_line" | grep -o 'post="[^"]*"' | cut -d'"' -f2)
	fi

	# Log parsed configuration for debugging
	info "Parsed tool config for $tool_name: type=$TOOL_VERSION_TYPE, config=$TOOL_CONFIG"
}

###############################################################################
# Repository Management
###############################################################################

# Configure Git to trust a repository directory
# Args:
#   $1: Repository directory
configure_git_trust() {
	local repo_dir="$1"

	# Make sure the directory exists
	if [ ! -d "$repo_dir" ]; then
		return 1
	fi

	# Add directory to git safe.directory config
	# Use sudo -E to preserve environment variables
	sudo -E git config --global --add safe.directory "$repo_dir"

	# Verify trust was added
	info "Added Git trust for repository: $repo_dir"

	return 0
}

# Setup tool repository in cache
# Args:
#   $1: Tool name
#   $2: Repository URL
setup_tool_repo() {
	local tool_name="$1"
	local repo_url="$2"
	local cache_dir="$CACHE_DIR/$tool_name"

	# Ensure the directories exist with proper permissions
	ensure_dir_permissions "$cache_dir"

	# Ensure the cache directory and its contents are owned by root:staff with write permissions
	sudo chown -R root:staff "$cache_dir"
	sudo chmod -R 775 "$cache_dir"

	if [ ! -d "$cache_dir/.git" ]; then
		info "Cloning $tool_name repository..."
		# Clone as sudo but ensure proper permissions afterward
		sudo -u root git clone "$repo_url" "$cache_dir" || error "Failed to clone repository"
		sudo chown -R root:staff "$cache_dir"
		sudo chmod -R 775 "$cache_dir"
	else
		info "Updating $tool_name repository..."
		# Make sure git trusts this directory
		configure_git_trust "$cache_dir"

		# Use sudo for git operations to avoid permission issues
		(cd "$cache_dir" && sudo -u root git fetch) || error "Failed to update repository"
	fi

	# Always ensure the repository is trusted after operations
	configure_git_trust "$cache_dir"

	echo "$cache_dir"
}

# Perform a git checkout with proper permissions
# Args:
#   $1: Repository directory
#   $2: Branch or tag to checkout
git_checkout_safe() {
	local repo_dir="$1"
	local checkout_target="$2"

	# Ensure the repository is trusted
	configure_git_trust "$repo_dir"

	# Remove any existing lock files
	if [ -f "$repo_dir/.git/index.lock" ]; then
		sudo rm -f "$repo_dir/.git/index.lock"
	fi

	# Fix permissions
	sudo chown -R root:staff "$repo_dir"
	sudo chmod -R g+w "$repo_dir/.git"

	# Use sudo for the git operation
	(cd "$repo_dir" && sudo -u root git checkout "$checkout_target")
	return $?
}

###############################################################################
# Version Management
###############################################################################

# Get the target version for a tool
# Args:
#   $1: Repository directory
#   $2: Version type (stable|head)
get_target_version() {
	local repo_dir="$1"
	local version_type="$2"

	if [ "$version_type" != "stable" ]; then
		echo ""
		return 0
	fi

	# Get the latest tag that looks like a version number
	(cd "$repo_dir" && sudo git fetch --tags && sudo git tag -l | grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -n1)
}

###############################################################################
# Build Management
###############################################################################

# Configure build flags
configure_build_flags() {
	local cpu_count
	if command -v nproc >/dev/null 2>&1; then
		cpu_count=$(nproc)
	else
		cpu_count=2 # Default to 2 if nproc is not available
	fi

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

	if [ -n "${TOOL_POST_COMMAND:-}" ]; then
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

	# Parse tool configuration
	parse_tool_config "$tool_name"

	# Print the parsed configuration for debugging
	info "Tool $tool_name configuration: version_type=$TOOL_VERSION_TYPE"

	# Process based on version type
	case "$TOOL_VERSION_TYPE" in
	none)
		info "Skipping $tool_name as configured (none)"
		return 0
		;;
	managed)
		info "Installing $tool_name via package manager (managed)"
		package_install "$tool_name"
		return $?
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
