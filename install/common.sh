#!/usr/bin/env bash

# Purpose:
# This script provides common functionality for installing and managing development tools
# in a multi-user environment. It handles:
# - Environment setup using zsh configurations in a bash context
# - Package management across different Linux distributions
# - Development toolchain management (Rust, Go, Python/conda)
# - Tool installation from source with version management
# - Configuration management for installed tools
#
# The script is designed to be sourced by individual tool installation scripts
# and provides a consistent interface for managing tool installations.

###############################################################################
# Section 1: Environment Setup and Basic Utilities
# Purpose: Initialize the environment and provide basic utility functions.
# This section handles:
# - Reading zsh configuration in a bash context
# - Setting up basic paths and directories
# - Providing logging and error handling functions
###############################################################################

# Setup environment from zsh configuration
# Strategy:
# 1. Read zshenv which contains our canonical environment setup
# 2. Filter out zsh-specific syntax that bash can't handle
# 3. Apply the configuration to our current environment
# This allows us to maintain a single source of truth for environment variables
setup_env() {
	set -f # Disable glob expansion to handle zsh configs safely
	local ZSHENV="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zshenv"

	# Filter zsh-specific syntax and eval the result
	export BASH_SOURCE_ZSHENV=$(grep -v '\[\[' "$ZSHENV")
	eval "$BASH_SOURCE_ZSHENV"
	set +f # Re-enable glob expansion

	# Set installation directories
	export INSTALL_DATA_DIR="${XDG_DATA_HOME}/zsh/install"
}

# Initialize environment
setup_env

# Logging and error handling functions
# These functions ensure consistent error reporting across all scripts
# All messages are sent to stderr to keep stdout clean for command output
info() { echo "[INFO] $1" >&2; }
warn() { echo "[WARN] $1" >&2; }
error() {
	echo "[ERROR] $1"
	exit 1
}

# Check if a command exists in PATH
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

###############################################################################
# Section 2: Package Management
# Purpose: Provide a unified interface for package management across distributions.
# This section handles:
# - Distribution detection
# - Package installation and removal
# - System package cleanup
###############################################################################

# Detect the system's package manager
# Strategy: Check /etc/os-release first, fall back to command availability
get_package_manager() {
	if [ -f /etc/os-release ]; then
		. /etc/os-release
		case "$ID" in
		debian | ubuntu | raspbian)
			echo "apt"
			;;
		fedora | rhel | centos)
			echo "dnf"
			;;
		arch | manjaro)
			echo "pacman"
			;;
		*)
			# Fallback to checking available package managers
			if command_exists apt; then
				echo "apt"
			elif command_exists dnf; then
				echo "dnf"
			elif command_exists pacman; then
				echo "pacman"
			else
				error "Unsupported distribution: $ID"
			fi
			;;
		esac
	else
		error "Cannot determine distribution type"
	fi
}

# Install a package using the appropriate package manager
package_install() {
	local pkg_name="$1"
	case "$(get_package_manager)" in
	apt)
		sudo apt update && sudo apt install -y "$pkg_name"
		;;
	dnf)
		sudo dnf install -y "$pkg_name"
		;;
	pacman)
		sudo pacman -Sy --noconfirm "$pkg_name"
		;;
	esac
}

# Remove a package and its unused dependencies
package_remove() {
	local pkg_name="$1"
	case "$(get_package_manager)" in
	apt)
		sudo apt remove -y "$pkg_name" && sudo apt autoremove -y
		;;
	dnf)
		sudo dnf remove -y "$pkg_name" && sudo dnf autoremove -y
		;;
	pacman)
		sudo pacman -Rs --noconfirm "$pkg_name"
		;;
	esac
}

# Remove a packaged version of a tool before building from source
remove_packaged_version() {
	local package_name="$1"

	case "$(get_package_manager)" in
	apt)
		if dpkg -l "$package_name" >/dev/null 2>&1; then
			info "Removing package manager version of $package_name"
			package_remove "$package_name"
		fi
		;;
	dnf)
		if dnf list installed "$package_name" >/dev/null 2>&1; then
			info "Removing package manager version of $package_name"
			package_remove "$package_name"
		fi
		;;
	pacman)
		if pacman -Qi "$package_name" >/dev/null 2>&1; then
			info "Removing package manager version of $package_name"
			package_remove "$package_name"
		fi
		;;
	esac
}

###############################################################################
# Section 3: Toolchain Management
# Purpose: Manage development toolchains (Rust, Go, Python/conda)
# This section handles:
# - Installation and updates of development toolchains
# - System-wide installation configuration
# - Version management
###############################################################################

# Get the appropriate system-wide installation directory
# Strategy: Check for /opt/local first, then /usr/local
get_system_install_dir() {
	if [ -d "/opt/local" ]; then
		echo "/opt/local"
	else
		echo "/usr/local"
	fi
}

# Ensure Rust toolchain is installed and up to date
ensure_rust_toolchain() {
	# Remove any system-packaged Rust first
	remove_packaged_version "rust"
	remove_packaged_version "cargo"

	# Install and configure rustup if not present
	if ! command_exists rustup; then
		info "Installing rustup..."
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
		source "$HOME/.cargo/env"
	fi

	info "Updating Rust toolchain..."
	rustup update stable

	# Ensure cargo is in PATH
	if ! command_exists cargo; then
		source "$HOME/.cargo/env"
	fi
}

# Get the latest stable Go version
get_latest_go_version() {
	local version_info
	version_info=$(curl -s https://go.dev/dl/?mode=json | grep -o '"version": "go[0-9.]*"' | head -1)
	echo "$version_info" | grep -o '[0-9.]*'
}

# Ensure Go toolchain is installed and up to date
ensure_go_toolchain() {
	# Remove any system-packaged Go
	remove_packaged_version "golang-go" # Debian-based
	remove_packaged_version "golang"    # RPM-based
	remove_packaged_version "go"        # Arch-based

	local latest_version=$(get_latest_go_version)
	local install_dir=$(get_system_install_dir)

	# Install/update Go if needed
	if ! command_exists go || [[ "$(go version | awk '{print $3}')" != "go${latest_version}" ]]; then
		info "Installing/Updating Go to version ${latest_version}..."
		local ARCH="arm64" # Adjust based on system architecture
		local OS="linux"

		wget "https://go.dev/dl/go${latest_version}.${OS}-${ARCH}.tar.gz" -O /tmp/go.tar.gz
		sudo rm -rf "${install_dir}/go"
		sudo tar -C "${install_dir}" -xzf /tmp/go.tar.gz
		rm /tmp/go.tar.gz

		# Ensure binary directory is in PATH
		if [[ ":$PATH:" != *":${install_dir}/go/bin:"* ]]; then
			export PATH=$PATH:${install_dir}/go/bin
		fi
	fi
}

# Ensure Conda is installed and configured system-wide
ensure_conda() {
	local install_dir=$(get_system_install_dir)
	local conda_dir="${install_dir}/conda"

	if ! command_exists conda; then
		info "Installing Miniconda system-wide..."
		wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O /tmp/miniconda.sh
		sudo bash /tmp/miniconda.sh -b -p "$conda_dir"
		rm /tmp/miniconda.sh

		# Set permissions for multi-user access
		sudo chmod -R a+rwx "$conda_dir"

		# Initialize for current shell
		eval "$("$conda_dir/bin/conda" shell.bash hook)"
	else
		info "Updating Conda installation..."
		conda update -n base -c defaults conda -y
	fi
}

# Setup Python environment for a tool
setup_python_env() {
	local tool_name="$1"
	local env_name="python_env_${tool_name}"

	ensure_conda

	# Create or update environment
	if conda env list | grep -q "^${env_name}"; then
		info "Updating Python environment for ${tool_name}"
		conda activate "$env_name" || error "Failed to activate environment"
		conda update --all -y
	else
		info "Creating Python environment for ${tool_name}"
		conda create -y -n "$env_name" python=3 || error "Failed to create environment"
		conda activate "$env_name" || error "Failed to activate environment"
	fi
}

###############################################################################
# Section 4: Version Management
# Purpose: Handle version detection, comparison, and management
# This section provides functions for:
# - Version extraction and comparison
# - Repository version management
# - Installation state tracking
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

# Get version of installed binary
get_installed_binary_version() {
	local binary="$1"
	local version_cmd="$2"

	if ! command_exists "$binary"; then
		echo "not_installed"
		return
	fi

	# Some commands output version to stdout, others to stderr
	local version_output
	version_output=$("$binary" "$version_cmd" 2>&1)

	# Extract version number (handles different version formats)
	local version
	version=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)

	if [ -n "$version" ]; then
		echo "$version"
	else
		echo "unknown"
	fi
}

# Get the target version from a repository
get_target_version() {
	local repo_dir="$1"
	local version_type="$2"
	local prefix="${3:-v}"

	cd "$repo_dir" 2>/dev/null || error "Failed to enter repository directory"

	if [ "$version_type" = "head" ]; then
		git ls-remote origin HEAD | cut -f1
	else
		# Get all tags and sort by version number
		local latest_version
		latest_version=$(git ls-remote --tags --refs origin |
			cut -d'/' -f3 |
			grep "^${prefix}" |
			grep -v '[ab]' |
			sort -t. -k1,1n -k2,2n -k3,3n |
			tail -n1)

		if [ -z "$latest_version" ]; then
			error "No valid version tags found"
		fi
		echo "$latest_version"
	fi
}

###############################################################################
# Section 5: Repository and Tool Management
# Purpose: Handle tool repository management and installation
# This section provides functions for:
# - Repository setup and maintenance
# - Build configuration
# - Tool configuration management
###############################################################################

# Setup tool repository
setup_tool_repo() {
	local tool_name="$1"
	local repo_url="$2"
	local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/tools/$tool_name"

	mkdir -p "$(dirname "$cache_dir")"

	if [ ! -d "$cache_dir" ] || [ -z "$(ls -A "$cache_dir" 2>/dev/null)" ]; then
		info "Cloning $tool_name repository..." >&2
		rm -rf "$cache_dir"
		git clone "$repo_url" "$cache_dir" || error "Failed to clone $tool_name repository"
	else
		info "Updating $tool_name repository..." >&2
		(cd "$cache_dir" && git fetch) || error "Failed to update $tool_name repository"
	fi

	echo "$cache_dir"
}

# Configure build flags for compilation
configure_build_flags() {
	local cpu_count=$(nproc)
	# On resource-constrained systems, use one less than available cores
	export MAKE_FLAGS="-j$((cpu_count - 1))"
}

# Parse tool configuration from tools.conf
parse_tool_config() {
	local tool_name="$1"
	local config_line="${!tool_name:-stable}" # Default to stable if not set

	# Split the line on comma and trim spaces
	if [[ "$config_line" == *","* ]]; then
		local parts=(${config_line//,/ })
		TOOL_VERSION_TYPE="${parts[0]}"
		local config_flag="${parts[1]}"

		# Convert config flag to boolean
		if [[ "${config_flag,,}" == "config" ]]; then
			TOOL_CONFIG_NEEDED=1
		else
			TOOL_CONFIG_NEEDED=0
		fi
	else
		# No config specified, default to noconfig
		TOOL_VERSION_TYPE="$config_line"
		TOOL_CONFIG_NEEDED=0
	fi
}

# Install tool configuration if needed
install_tool_config() {
	local tool_name="$1"
	local binary_name="${2:-$tool_name}"

	# Skip if configuration is not needed
	if [ "$TOOL_CONFIG_NEEDED" != "1" ]; then
		return 0
	fi

	local config_repo="https://github.com/ChrisGVE/config.${binary_name}.git"
	local config_dir="${XDG_CONFIG_HOME}/${binary_name}"

	if ! curl --output /dev/null --silent --head --fail "$config_repo"; then
		warn "No configuration repository found for $tool_name"
		return 0
	fi

	info "Installing configuration for $tool_name"
	if [ -d "$config_dir" ]; then
		mv "$config_dir" "${config_dir}.backup.$(date +%Y%m%d%H%M%S)"
	fi
	git clone "$config_repo" "$config_dir" || error "Failed to clone configuration for $tool_name"
}

###############################################################################
# Section 6: Main Installation Function
# Purpose: Provide the main entry point for tool installation
# This is the highest-level function that orchestrates:
# - Tool configuration parsing
# - Version management
# - Installation process
# - Configuration setup
###############################################################################

# Main tool installation function
install_or_update_tool() {
	local tool_name="$1"
	local binary="$2"
	local version_cmd="$3"
	local repo_dir="$4"
	local build_func="$5"

	# Parse tool configuration
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
		if [ "$TOOL_VERSION_TYPE" = "stable" ]; then
			local target_version=$(get_target_version "$repo_dir" "stable")
			local current_version=$(get_installed_binary_version "$binary" "$version_cmd")

			# Only proceed if versions differ or tool is not installed
			if [ "$current_version" != "not_installed" ] && [ "$current_version" != "unknown" ]; then
				if [ "$(echo "$current_version" | tr -d 'v')" = "$(echo "$target_version" | tr -d 'v')" ]; then
					info "$tool_name is already at latest version $target_version"
					return 0
				fi
			fi
		fi

		# Build from source
		"$build_func" "$repo_dir" "$TOOL_VERSION_TYPE"
		;;
	*)
		error "Invalid version type: $TOOL_VERSION_TYPE"
		;;
	esac

	# Install configuration if needed
	install_tool_config "$tool_name" "$binary"
}
