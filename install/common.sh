#!/usr/bin/env bash

# Setup environment
setup_env() {
	set -f # Disable glob expansion
	local ZSHENV="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zshenv"
	export BASH_SOURCE_ZSHENV=$(grep -v '\[\[' "$ZSHENV")
	eval "$BASH_SOURCE_ZSHENV"
	set +f # Re-enable glob expansion

	# Set installation directories
	export INSTALL_DATA_DIR="${XDG_DATA_HOME}/zsh/install"
}

# Initialize environment
setup_env

# Print status messages
info() { echo "[INFO] $1" >&2; }
warn() { echo "[WARN] $1" >&2; }
error() {
	echo "[ERROR] $1"
	exit 1
}

# Check if a command exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Detect distribution and package manager
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
			if command -v apt >/dev/null 2>&1; then
				echo "apt"
			elif command -v dnf >/dev/null 2>&1; then
				echo "dnf"
			elif command -v pacman >/dev/null 2>&1; then
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

# Package manager abstraction
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

# Setup Python environment for a tool
setup_python_env() {
	local tool_name="$1"
	local env_name="python_env_${tool_name}"

	if ! command_exists conda; then
		error "Conda is not installed"
	fi

	# Create or update environment
	if conda env list | grep -q "^${env_name}"; then
		info "Updating Python environment for ${tool_name}"
		conda activate "$env_name" || error "Failed to activate environment"
	else
		info "Creating Python environment for ${tool_name}"
		conda create -y -n "$env_name" python=3 || error "Failed to create environment"
		conda activate "$env_name" || error "Failed to activate environment"
	fi
}

# Parse tool configuration
# Args:
#   $1: tool name
# Returns:
#   Sets global variables:
#   - TOOL_VERSION_TYPE (stable|head|managed|none)
#   - TOOL_CONFIG_NEEDED (0|1)
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

# Setup tool repository
# Args:
#   $1: tool name
#   $2: repository URL
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

	printf "%s\n" "$cache_dir"
}

# Configure build flags
configure_build_flags() {
	local cpu_count=$(nproc)
	# On Raspberry Pi, use one less than available cores to prevent lockup
	export MAKE_FLAGS="-j$((cpu_count - 1))"
}

# Get the target version (stable or head) for a tool
# Args:
#   $1: repository directory
#   $2: version type (stable|head)
#   $3: optional version prefix for stable versions (default: "v")
get_target_version() {
	local repo_dir="$1"
	local version_type="$2"
	local prefix="${3:-v}"

	if [ "$version_type" = "head" ]; then
		(cd "$repo_dir" 2>/dev/null && git ls-remote origin HEAD | cut -f1)
	else
		(cd "$repo_dir" 2>/dev/null &&
			git ls-remote --tags --refs origin |
			cut -d'/' -f3 |
				grep "^${prefix}" |
				grep -v '[ab]' |
				sort -V |
				tail -n1)
	fi
}

# Install tool configuration if needed
# Args:
#   $1: tool name (as in config.toolname)
#   $2: binary name (optional, defaults to tool name)
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
		# Remove packaged version if exists
		if command_exists "$binary"; then
			remove_packaged_version "$binary"
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
