#!/usr/bin/env bash

###############################################################################
# Common Functions Library
#
# Purpose:
# Provides shared functionality for the development tools management system.
# This script handles:
# - Platform detection and adaptation
# - Directory and permission management
# - Version detection and comparison
# - Tool configuration parsing
# - Common installation procedures
# - Post-installation tasks
#
# Environment:
# Uses platform-appropriate permissions and ownership
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
# Platform Detection
###############################################################################

# Detect platform and set platform-specific variables
detect_platform() {
	# Detect OS (macos, linux, raspberrypi)
	case "$(uname -s)" in
	Darwin*)
		export OS_TYPE="macos"
		export ADMIN_GROUP="admin"
		if command -v brew >/dev/null 2>&1; then
			export HOMEBREW_PREFIX="$(brew --prefix)"
		else
			warn "Homebrew not found on macOS"
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

		# Determine appropriate admin group
		if getent group sudo >/dev/null; then
			export ADMIN_GROUP="sudo"
		elif getent group wheel >/dev/null; then
			export ADMIN_GROUP="wheel"
		elif getent group adm >/dev/null; then
			export ADMIN_GROUP="adm"
		else
			error "Could not determine appropriate admin group"
		fi
		;;
	*)
		error "Unsupported operating system"
		;;
	esac

	info "Detected platform: $OS_TYPE with admin group: $ADMIN_GROUP"
}

###############################################################################
# Base Directory Management
###############################################################################

# Get the base installation directory
# Will be either /opt/local or /usr/local
get_base_dir() {
	# Check if user has write access to /opt/local
	if [ -d "/opt/local" ] && sudo -n test -w "/opt/local" 2>/dev/null; then
		echo "/opt/local"
	# Check if user has write access to /usr/local (via sudo)
	elif [ -d "/usr/local" ] && sudo -n test -w "/usr/local" 2>/dev/null; then
		echo "/usr/local"
	# If neither is directly writable, prefer /opt/local with sudo
	elif sudo -n mkdir -p "/opt/local" 2>/dev/null; then
		echo "/opt/local"
	# Fall back to /usr/local with sudo
	elif sudo -n mkdir -p "/usr/local" 2>/dev/null; then
		echo "/usr/local"
	else
		error "Cannot determine or create usable installation directory"
	fi
}

# Initialize common paths and variables
init_common_vars() {
	# Detect platform
	detect_platform

	# Set up base directories and paths
	BASE_DIR="$(get_base_dir)"
	export BASE_DIR

	CACHE_DIR="$BASE_DIR/share/dev/cache"
	CONFIG_DIR="$BASE_DIR/etc/dev"
	TOOLS_CONF="$CONFIG_DIR/tools.conf"

	export CACHE_DIR CONFIG_DIR TOOLS_CONF

	info "Using base directory: $BASE_DIR"
}

###############################################################################
# Package Manager Operations
###############################################################################

# Detect package manager
detect_package_manager() {
	# macOS uses Homebrew
	if [[ "$OS_TYPE" == "macos" ]]; then
		if command -v brew >/dev/null 2>&1; then
			export PACKAGE_MANAGER="brew"
			return 0
		else
			error "Homebrew not found but required for macOS"
		fi
	fi

	# For Linux flavors
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		case "$ID" in
		debian | ubuntu | raspbian)
			export PACKAGE_MANAGER="apt"
			;;
		fedora | rhel | centos)
			export PACKAGE_MANAGER="dnf"
			;;
		arch | manjaro)
			export PACKAGE_MANAGER="pacman"
			;;
		*)
			# Fallback to checking available package managers
			if command -v apt >/dev/null 2>&1; then
				export PACKAGE_MANAGER="apt"
			elif command -v dnf >/dev/null 2>&1; then
				export PACKAGE_MANAGER="dnf"
			elif command -v pacman >/dev/null 2>&1; then
				export PACKAGE_MANAGER="pacman"
			else
				error "Unsupported distribution: $ID"
			fi
			;;
		esac
	else
		error "Cannot determine distribution type"
	fi

	info "Detected package manager: $PACKAGE_MANAGER"
	return 0
}

# Install a package using the appropriate package manager
package_install() {
	local package_name="$1"
	info "Installing package: $package_name"

	# Detect package manager if not already set
	if [ -z "${PACKAGE_MANAGER:-}" ]; then
		detect_package_manager
	fi

	case "$PACKAGE_MANAGER" in
	brew)
		brew install "$package_name"
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y "$package_name"
		;;
	dnf)
		sudo dnf install -y "$package_name"
		;;
	pacman)
		sudo pacman -Sy --noconfirm "$package_name"
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
		sudo chown -R root:$ADMIN_GROUP "$dir"
	else
		sudo chmod "$perms" "$dir"
		sudo chown root:$ADMIN_GROUP "$dir"
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
	sudo chown -h root:$ADMIN_GROUP "$target"
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

# Get the currently installed version of a tool
# Args:
#   $1: Binary name
#   $2: Version command (e.g., --version)
get_installed_version() {
	local binary="$1"
	local version_cmd="$2"

	if command -v "$binary" >/dev/null 2>&1; then
		# Try to extract version number from output
		local version_output=$("$binary" $version_cmd 2>&1 | head -n1)

		# Extract version number using regex patterns for common formats
		local version=$(echo "$version_output" | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)

		if [[ -z "$version" ]]; then
			# Try alternative pattern for version extraction
			version=$(echo "$version_output" | grep -o -E 'version [0-9]+\.[0-9]+(\.[0-9]+)?' | grep -o -E '[0-9]+\.[0-9]+(\.[0-9]+)?')
		fi

		echo "$version"
	else
		echo ""
	fi
}

###############################################################################
# Tool Configuration Management
###############################################################################

# Parse tool configuration from tools.conf
# Args:
#   $1: Tool name
# Sets global variables:
#   TOOL_VERSION_TYPE: stable|head|managed|none
#   TOOL_CONFIG: true|false
#   TOOL_POST_COMMAND: Command to run after installation
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
		TOOL_CONFIG="false"
		TOOL_POST_COMMAND=""
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

# Configure Git to trust a repository directory - using a safer approach
# Args:
#   $1: Repository directory
configure_git_trust() {
	local repo_dir="$1"

	# Make sure the directory exists
	if [ ! -d "$repo_dir" ]; then
		return 1
	fi

	# Use a local .git/config instead of global config
	(cd "$repo_dir" && sudo git config --local --bool core.trustctime false)

	# Make the repo directory writable by the git process
	sudo chmod -R g+w "$repo_dir"

	# Set ownership to ensure git can write to the repo
	sudo chown -R root:$ADMIN_GROUP "$repo_dir"

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

	# Create cache directory if it doesn't exist
	if [ ! -d "$CACHE_DIR" ]; then
		sudo mkdir -p "$CACHE_DIR"
		sudo chown root:$ADMIN_GROUP "$CACHE_DIR"
		sudo chmod 775 "$CACHE_DIR"
	fi

	# Check if repository directory exists
	if [ ! -d "$cache_dir" ]; then
		info "Cloning $tool_name repository..."
		# Clone into a temporary directory first
		local temp_dir=$(mktemp -d)
		if git clone "$repo_url" "$temp_dir"; then
			# Create the target directory
			sudo mkdir -p "$cache_dir"
			sudo chown root:$ADMIN_GROUP "$cache_dir"
			sudo chmod 775 "$cache_dir"

			# Move content to final location using sudo
			sudo cp -a "$temp_dir/." "$cache_dir/"
			rm -rf "$temp_dir"

			# Ensure proper permissions
			sudo chown -R root:$ADMIN_GROUP "$cache_dir"
			sudo chmod -R 775 "$cache_dir"
		else
			error "Failed to clone repository: $repo_url"
			rm -rf "$temp_dir"
			return 1
		fi
	else
		info "Updating $tool_name repository..."

		# Always create fresh .git/config to avoid issues with safe.directory
		if [ -f "$cache_dir/.git/config" ]; then
			sudo rm -f "$cache_dir/.git/config"
			(cd "$cache_dir" && sudo git init -q)
			(cd "$cache_dir" && sudo git remote add origin "$repo_url")
		fi

		# Configure git trust for this repository
		(cd "$cache_dir" && sudo git config --local --bool core.trustctime false)
		(cd "$cache_dir" && sudo git config --local --bool core.filemode false)

		# Set permissions for git operations
		sudo chmod -R g+w "$cache_dir"

		# Clean and reset the repository
		(cd "$cache_dir" && sudo git clean -fd) || warn "Failed to clean repository"
		(cd "$cache_dir" && sudo git reset --hard) || warn "Failed to reset repository"

		# Fetch updates
		(cd "$cache_dir" && sudo git fetch) || error "Failed to update repository"
	fi

	# Final verification
	if [ ! -d "$cache_dir/.git" ]; then
		error "Repository setup failed: $cache_dir is not a git repository"
		return 1
	fi

	echo "$cache_dir"
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
	(cd "$repo_dir" && git fetch --tags && git tag -l | grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -n1)
}

###############################################################################
# Build Management
###############################################################################

# Function to ensure Rust/Cargo is available before building
ensure_rust_available() {
	# Check if cargo is in PATH
	if ! command -v cargo >/dev/null 2>&1; then
		info "Cargo not found in PATH, checking for Rust installation..."

		# Check for Rust in our toolchain location
		local rust_cargo="$BASE_DIR/share/dev/toolchains/rust/cargo/bin/cargo"

		if [ -f "$rust_cargo" ]; then
			info "Found Cargo at $rust_cargo, adding to PATH"
			export PATH="$BASE_DIR/share/dev/toolchains/rust/cargo/bin:$PATH"
			export RUSTUP_HOME="$BASE_DIR/share/dev/toolchains/rust/rustup"
			export CARGO_HOME="$BASE_DIR/share/dev/toolchains/rust/cargo"
		else
			# Rust isn't installed or isn't in PATH, try to install it
			info "Rust not found in expected location, attempting installation..."

			# Source toolchains.sh to get install_rust function
			if [ -f "$CONFIG_DIR/toolchains.sh" ]; then
				source "$CONFIG_DIR/toolchains.sh"
				install_rust || error "Failed to install Rust"

				# Add newly installed Rust to PATH
				export PATH="$BASE_DIR/share/dev/toolchains/rust/cargo/bin:$PATH"
				export RUSTUP_HOME="$BASE_DIR/share/dev/toolchains/rust/rustup"
				export CARGO_HOME="$BASE_DIR/share/dev/toolchains/rust/cargo"
			else
				error "Cannot find toolchains.sh to install Rust"
			fi
		fi
	fi

	# Final verification
	if ! command -v cargo >/dev/null 2>&1; then
		error "Cargo still not available in PATH after setup attempts"
		return 1
	fi

	info "Rust/Cargo is available: $(cargo --version)"
	return 0
}

# Configure build flags
configure_build_flags() {
	local cpu_count
	if command -v nproc >/dev/null 2>&1; then
		cpu_count=$(nproc)
	elif [ "$OS_TYPE" = "macos" ] && command -v sysctl >/dev/null 2>&1; then
		cpu_count=$(sysctl -n hw.ncpu)
	else
		cpu_count=2 # Default to 2 if detection fails
	fi

	# Use one less than available cores to prevent system lockup
	# But ensure at least 1 job
	local jobs=$((cpu_count - 1))
	[ "$jobs" -lt 1 ] && jobs=1

	export MAKE_FLAGS="-j$jobs"
	info "Build parallelism set to $jobs jobs"
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
		# Check if already installed
		local current_version=""
		if command -v "$BASE_DIR/bin/$binary" >/dev/null 2>&1; then
			current_version=$(get_installed_version "$BASE_DIR/bin/$binary" "$version_cmd")
			info "$tool_name is already installed (version: $current_version), checking for updates..."
		fi

		# For head version or when current_version is empty, always build
		local should_build=0
		if [ "$TOOL_VERSION_TYPE" = "head" ]; then
			should_build=1
			info "Building head version as configured"
		elif [ -z "$current_version" ]; then
			should_build=1
			info "No current version detected, building..."
		else
			# For stable version, check if newer version available
			local target_version=$(get_target_version "$repo_dir" "$TOOL_VERSION_TYPE")

			if [ -n "$target_version" ]; then
				# Strip 'v' prefix for comparison if present
				target_version=${target_version#v}
				current_version=${current_version#v}

				# Compare versions
				compare_versions "$target_version" "$current_version"
				local comp_result=$?

				if [ $comp_result -eq 0 ]; then
					should_build=1
					info "Newer version available: $target_version (current: $current_version)"
				elif [ $comp_result -eq 2 ]; then
					info "Already at latest version: $current_version"
				else
					warn "Current version ($current_version) is newer than target ($target_version). Strange!"
					# Build anyway to ensure consistency
					should_build=1
				fi
			else
				# If we can't determine target version, build anyway
				should_build=1
				info "Could not determine target version, building anyway"
			fi
		fi

		if [ $should_build -eq 1 ]; then
			# Build from source - call the function passed as parameter
			$build_func "$repo_dir" "$TOOL_VERSION_TYPE"
		fi
		;;
	*)
		error "Invalid version type: $TOOL_VERSION_TYPE"
		;;
	esac
}

# Initialize common variables
init_common_vars

# Detect package manager if we're running in a full script context
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	detect_package_manager
fi

# Export variables for other scripts
export PACKAGE_MANAGER OS_TYPE ADMIN_GROUP BASE_DIR
