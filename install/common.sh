#!/usr/bin/env bash

# Print status messages
info() { echo "[INFO] $1"; }
warn() { echo "[WARN] $1"; }
error() {
	echo "[ERROR] $1"
	exit 1
}

# Check if a command exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Load tool configuration
load_tool_config() {
	local config_file="${INSTALL_DATA_DIR}/tools.conf"
	if [ -f "$config_file" ]; then
		source "$config_file"
	else
		warn "No tools.conf found, defaulting to stable versions"
	fi
}

# Get the target version (stable or head) for a tool
# Args:
#   $1: tool name (uppercase, e.g., "NEOVIM")
get_tool_version_type() {
	local tool_name="$1"
	echo "${!tool_name:-stable}"
}

# Get git hash of current HEAD
# Args:
#   $1: repository directory
get_git_hash() {
	local repo_dir="$1"
	(cd "$repo_dir" && git rev-parse HEAD)
}

# Get the latest version/hash for a tool
# Args:
#   $1: repository directory
#   $2: version type (stable|head)
#   $3: optional version prefix for stable versions (default: "v")
get_target_version() {
	local repo_dir="$1"
	local version_type="$2"
	local prefix="${3:-v}"

	if [ "$version_type" = "head" ]; then
		(cd "$repo_dir" && git ls-remote origin HEAD | cut -f1)
	else
		(cd "$repo_dir" &&
			git ls-remote --tags --refs origin |
			cut -d'/' -f3 |
				grep "^${prefix}" |
				grep -v '[ab]' |
				sort -V |
				tail -n1)
	fi
}

# Setup tool repository
# Args:
#   $1: tool name
#   $2: repository URL
setup_tool_repo() {
	local tool_name="$1"
	local repo_url="$2"
	local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/tools/$tool_name"

	if [ ! -d "$cache_dir" ] || [ -z "$(ls -A "$cache_dir")" ]; then
		info "Cloning $tool_name repository..."
		rm -rf "$cache_dir"
		git clone "$repo_url" "$cache_dir" || error "Failed to clone $tool_name repository"
	else
		info "Updating $tool_name repository..."
		(cd "$cache_dir" && git fetch) || error "Failed to update $tool_name repository"
	fi

	echo "$cache_dir"
}

# Configure build flags
# Returns number of CPU cores to use via MAKE_FLAGS
configure_build_flags() {
	local cpu_count=$(nproc)
	# On Raspberry Pi, use one less than available cores to prevent lockup
	MAKE_FLAGS="-j$((cpu_count - 1))"
}

# Verify tool installation
# Args:
#   $1: binary name
#   $2: version command (e.g., "--version")
verify_installation() {
	local binary="$1"
	local version_cmd="$2"

	if ! command_exists "$binary"; then
		error "Installation verification failed - binary not found: $binary"
	fi

	if ! "$binary" "$version_cmd" >/dev/null 2>&1; then
		error "Installation verification failed - binary not working: $binary"
	fi

	info "Installation verified successfully for: $binary"
}

# Generic tool installation function
# Args:
#   $1: tool name
#   $2: binary name
#   $3: version command
#   $4: repository directory
#   $5: build function name
install_or_update_tool() {
	local tool_name="$1"
	local binary="$2"
	local version_cmd="$3"
	local repo_dir="$4"
	local build_func="$5"

	# Load configuration and get version type
	load_tool_config
	local version_type=$(get_tool_version_type "$tool_name")

	# Get current and target versions
	local target_version=$(get_target_version "$repo_dir" "$version_type")
	local current_hash=""

	if [ "$version_type" = "head" ]; then
		current_hash=$(get_git_hash "$repo_dir")
	fi

	# Check if update needed
	if [ "$version_type" = "head" ]; then
		if [ "$current_hash" = "$target_version" ]; then
			info "$tool_name is already at latest HEAD"
			return 0
		fi
	elif command_exists "$binary"; then
		info "$tool_name is already installed, checking for updates..."
		(cd "$repo_dir" && git checkout "$target_version") || error "Failed to checkout version $target_version"
		if [ "$(get_git_hash "$repo_dir")" = "$current_hash" ]; then
			info "$tool_name is already at latest version $target_version"
			return 0
		fi
	fi

	# Build tool using provided build function
	$build_func "$repo_dir" "$version_type" || error "Build failed for $tool_name"

	# Verify installation
	verify_installation "$binary" "$version_cmd"

	info "$tool_name installation/update completed successfully"
}
