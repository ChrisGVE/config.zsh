#!/usr/bin/env bash

###############################################################################
# Installation Script
#
# Purpose:
# This script handles the initial setup of the global development environment.
# It creates the necessary directory structure and installs core configuration
# files in system-wide locations.
#
# Directory Structure:
# /opt/local/ or /usr/local/    - Base installation directory
# ├── bin/                      - Executables and symlinks
# ├── etc/                      - Configuration files
# │   └── dev/                  - Development environment configuration
# │       ├── tools.conf       - Tool configuration
# │       ├── common.sh        - Common functions
# │       ├── toolchains.sh    - Toolchain management
# │       └── tools/           - Individual tool installers
# ├── share/                    - Shared data files
# │   └── dev/                 - Development tools shared data
# │       └── cache/          - Build and operation cache
# └── lib/                      - Libraries and dependencies
#
# This structure ensures:
# - All components are globally accessible
# - Clear separation between executables, configuration, and data
# - Consistent permissions and ownership
# - System-wide cache management
###############################################################################

set -euo pipefail

# Status message functions
info() { echo "[INFO] $1" >&2; }
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
# Directory Management
###############################################################################

# Determine the base installation directory
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

# Create directory structure with proper permissions
setup_directories() {
	local base_dir="$1"
	local dirs=(
		"$base_dir/bin"
		"$base_dir/etc/dev"
		"$base_dir/share/dev/cache"
		"$base_dir/lib"
	)

	info "Creating directory structure..."
	for dir in "${dirs[@]}"; do
		if [ ! -d "$dir" ]; then
			if ! sudo mkdir -p "$dir"; then
				error "Failed to create directory: $dir"
			fi
			sudo chown root:$ADMIN_GROUP "$dir"
			sudo chmod 775 "$dir"
			info "Created directory: $dir"
		fi
	done
}

###############################################################################
# Configuration Installation
###############################################################################

# Install configuration files and scripts
install_configs() {
	local base_dir="$1"
	local config_dir="$base_dir/etc/dev"
	local source_dir="$(dirname "$(readlink -f "$0")")"

	info "Installing configuration files..."

	# Install main configuration
	sudo cp "$source_dir/install/tools.conf" "$config_dir/"
	sudo cp "$source_dir/install/"*.sh "$config_dir/"
	sudo cp -r "$source_dir/install/tools" "$config_dir/"

	# Copy dependencies.sh from source directory root
	if [ -f "$source_dir/dependencies.sh" ]; then
		sudo cp "$source_dir/dependencies.sh" "$config_dir/"
	else
		error "dependencies.sh not found in $source_dir"
	fi

	# Set permissions
	sudo chown -R root:$ADMIN_GROUP "$config_dir"
	sudo chmod -R 775 "$config_dir"
	sudo chmod 664 "$config_dir/tools.conf"
	sudo chmod 775 "$config_dir/"*.sh
	sudo chmod 775 "$config_dir/tools/"*.sh

	info "Configuration files installed successfully"
}

# Create main executable
create_dependencies_command() {
	local base_dir="$1"
	local script_path="$base_dir/bin/dependencies"

	info "Creating dependencies command..."

	# Create the wrapper script
	cat <<EOF | sudo tee "$script_path" >/dev/null
#!/usr/bin/env bash
# Do not source common.sh here to avoid potential circular dependencies
# Use bash instead of exec to allow for better error handling
bash "$base_dir/etc/dev/dependencies.sh" "\$@"
EOF

	sudo chown root:$ADMIN_GROUP "$script_path"
	sudo chmod 775 "$script_path"

	info "Dependencies command created successfully"
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting global installation process..."

	# Detect platform
	detect_platform

	# Get base installation directory
	local base_dir="$(get_base_dir)"
	info "Using base directory: $base_dir"

	# Create directory structure
	setup_directories "$base_dir"

	# Install configuration files
	install_configs "$base_dir"

	# Create dependencies command
	create_dependencies_command "$base_dir"

	info "Installation complete. Use 'dependencies' command to manage development tools."
}

# Execute main installation process
main "$@"
