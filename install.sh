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
# Directory Management
###############################################################################

# Determine the base installation directory
get_base_dir() {
	if [ -d "/opt/local" ]; then
		echo "/opt/local"
	elif [ -d "/usr/local" ]; then
		echo "/usr/local"
	else
		# Default to /opt/local if neither exists
		echo "/opt/local"
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
			sudo chown root:staff "$dir"
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

	# Set permissions
	sudo chown -R root:staff "$config_dir"
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
source "$base_dir/etc/dev/common.sh"
exec "$base_dir/etc/dev/dependencies.sh" "\$@"
EOF

	sudo chown root:staff "$script_path"
	sudo chmod 775 "$script_path"

	info "Dependencies command created successfully"
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting global installation process..."

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
