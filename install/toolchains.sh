#!/usr/bin/env bash

###############################################################################
# Development Toolchains Management Script
#
# Purpose:
# This script manages core development toolchains in a system-wide configuration.
# It handles:
# - Python (via Miniconda)
# - Rust (via rustup)
# - Go
# - Zig
# - Perl
#
# Each toolchain is installed globally in the system directory structure:
# /opt/local/ or /usr/local/
# ├── bin/              - Toolchain executables and symlinks
# ├── lib/              - Libraries and dependencies
# └── share/
#     └── dev/
#         └── toolchains/  - Toolchain-specific files
#             ├── conda/   - Miniconda installation
#             ├── rust/    - Rust toolchain
#             ├── go/      - Go installation
#             ├── zig/     - Zig compiler
#             └── perl/    - Perl installation
#
# Features:
# - System-wide installations
# - Consistent permissions (root:staff, 775)
# - Version tracking
# - Proper PATH management via symlinks
###############################################################################

set -euo pipefail

# Source common functions
source "$(dirname "$0")/common.sh"

# Track toolchain states for summary
declare -A TOOLCHAIN_STATES
declare -A TOOLCHAIN_VERSIONS

###############################################################################
# Toolchain Installation Directory Management
###############################################################################

setup_toolchain_dirs() {
	# Create main toolchains directory
	local toolchains_dir="$BASE_DIR/share/dev/toolchains"
	ensure_dir_permissions "$toolchains_dir"

	# Create individual toolchain directories
	local dirs=(
		"$toolchains_dir/conda"
		"$toolchains_dir/rust"
		"$toolchains_dir/go"
		"$toolchains_dir/zig"
		"$toolchains_dir/perl"
	)

	for dir in "${dirs[@]}"; do
		ensure_dir_permissions "$dir"
	done
}

###############################################################################
# Python/Conda Management
###############################################################################

install_miniconda() {
	local conda_dir="$BASE_DIR/share/dev/toolchains/conda"
	local conda_bin="$conda_dir/bin/conda"

	info "Processing Miniconda installation..."

	if [ ! -f "$conda_bin" ]; then
		# If conda directory exists but binary doesn't, remove the directory
		if [ -d "$conda_dir" ]; then
			info "Conda directory exists but binary not found. Removing directory..."
			sudo rm -rf "$conda_dir"
		fi

		# Create directory with proper permissions
		sudo mkdir -p "$conda_dir"
		sudo chown root:staff "$conda_dir"
		sudo chmod 775 "$conda_dir"

		# Download installer
		local tmp_installer="/tmp/miniconda.sh"
		curl -L "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(uname -m).sh" -o "$tmp_installer"

		# Run installer with sudo to avoid permission issues
		sudo bash "$tmp_installer" -b -p "$conda_dir"
		rm -f "$tmp_installer"

		# Set permissions
		ensure_dir_permissions "$conda_dir" "775" true

		# Create symlinks
		create_managed_symlink "$conda_bin" "$BASE_DIR/bin/conda"
		create_managed_symlink "$conda_dir/bin/python" "$BASE_DIR/bin/python3"

		# Check if installation was successful
		if [ ! -f "$conda_bin" ]; then
			error "Miniconda installation failed. Binary not found at $conda_bin"
		fi

		TOOLCHAIN_STATES["conda"]="installed"
		TOOLCHAIN_VERSIONS["conda"]=$("$conda_bin" --version | cut -d' ' -f2)
	else
		# Update existing installation
		info "Updating existing Miniconda installation..."
		sudo -E "$conda_bin" update -n base -c defaults conda -y
		TOOLCHAIN_STATES["conda"]="updated"
		TOOLCHAIN_VERSIONS["conda"]=$("$conda_bin" --version | cut -d' ' -f2)
	fi
}

###############################################################################
# Rust Management
###############################################################################

install_rust() {
	local rust_dir="$BASE_DIR/share/dev/toolchains/rust"

	info "Processing Rust toolchain..."

	# Create initial required directories with proper permissions
	sudo mkdir -p "$rust_dir/rustup"
	sudo mkdir -p "$rust_dir/cargo"
	sudo chown -R root:staff "$rust_dir"
	sudo chmod -R 775 "$rust_dir"

	# Check if rustup is already installed and working
	local rustup_exists=0
	if [ -f "$rust_dir/cargo/bin/rustup" ] && [ -x "$rust_dir/cargo/bin/rustup" ]; then
		rustup_exists=1
	fi

	if [ "$rustup_exists" -eq 0 ]; then
		info "Installing Rust toolchain..."

		# Download rustup installer
		local tmp_installer="/tmp/rustup-init.sh"
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "$tmp_installer"
		chmod +x "$tmp_installer"

		# Clear any existing installation that might be incomplete
		if [ -d "$rust_dir" ]; then
			info "Removing existing incomplete Rust installation..."
			sudo rm -rf "$rust_dir"
			sudo mkdir -p "$rust_dir/rustup"
			sudo mkdir -p "$rust_dir/cargo"
			sudo chown -R root:staff "$rust_dir"
			sudo chmod -R 775 "$rust_dir"
		fi

		# Initialize Rust installation with correct permissions
		info "Running rustup installer..."
		(cd /tmp &&
			sudo -E env \
				RUSTUP_HOME="$rust_dir/rustup" \
				CARGO_HOME="$rust_dir/cargo" \
				bash "$tmp_installer" -y --no-modify-path)

		rm -f "$tmp_installer"

		# Fix permissions again after installation
		sudo chown -R root:staff "$rust_dir"
		sudo chmod -R 775 "$rust_dir"
	else
		# Update existing installation
		info "Updating existing Rust installation..."
		(cd /tmp &&
			sudo -E env \
				RUSTUP_HOME="$rust_dir/rustup" \
				CARGO_HOME="$rust_dir/cargo" \
				"$rust_dir/cargo/bin/rustup" update)
	fi

	# Create symlinks only if the binaries exist
	if [ -f "$rust_dir/cargo/bin/cargo" ]; then
		create_managed_symlink "$rust_dir/cargo/bin/cargo" "$BASE_DIR/bin/cargo"
	else
		warn "Cargo binary not found at $rust_dir/cargo/bin/cargo"
	fi

	if [ -f "$rust_dir/cargo/bin/rustc" ]; then
		create_managed_symlink "$rust_dir/cargo/bin/rustc" "$BASE_DIR/bin/rustc"
	else
		warn "Rustc binary not found at $rust_dir/cargo/bin/rustc"
	fi

	if [ -f "$rust_dir/cargo/bin/rustup" ]; then
		create_managed_symlink "$rust_dir/cargo/bin/rustup" "$BASE_DIR/bin/rustup"
	else
		warn "Rustup binary not found at $rust_dir/cargo/bin/rustup"
	fi

	# Capture version with more reliable method
	local rust_version=""
	if [ -f "$rust_dir/cargo/bin/rustc" ]; then
		rust_version=$(RUSTUP_HOME="$rust_dir/rustup" CARGO_HOME="$rust_dir/cargo" "$rust_dir/cargo/bin/rustc" --version | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+")

		if [ -z "$rust_version" ]; then
			# Fallback method if regex fails
			rust_version=$(RUSTUP_HOME="$rust_dir/rustup" CARGO_HOME="$rust_dir/cargo" "$rust_dir/cargo/bin/rustc" --version | awk '{print $2}')
		fi

		TOOLCHAIN_STATES["rust"]="installed"
		TOOLCHAIN_VERSIONS["rust"]="$rust_version"
		info "Rust version detected: $rust_version"
	else
		TOOLCHAIN_STATES["rust"]="failed"
		TOOLCHAIN_VERSIONS["rust"]="unknown"
		warn "Rust installation may not have completed successfully"
	fi
}

###############################################################################
# Go Management
###############################################################################

install_go() {
	local go_dir="$BASE_DIR/share/dev/toolchains/go"

	info "Processing Go toolchain..."

	# Safely get current version if Go is installed
	local current_version=""
	if command -v go >/dev/null 2>&1; then
		current_version=$(go version 2>/dev/null | grep -o 'go[0-9.]*' | grep -o '[0-9.]*' || echo "")
	fi

	# Get latest version with error handling
	local version=""
	local version_json=$(curl -s https://go.dev/dl/?mode=json || echo '{}')
	if [ -n "$version_json" ] && [ "$version_json" != "{}" ]; then
		version=$(echo "$version_json" | grep -o '"version": "go[0-9.]*"' | head -1 | grep -o '[0-9.]*' || echo "")
	fi

	if [ -z "$version" ]; then
		warn "Could not determine latest Go version. Using fallback version 1.21.1"
		version="1.21.1"
	fi

	# Determine if we need to install or update
	if [ ! -d "$go_dir" ] || [ -z "$current_version" ] || [ "$current_version" != "$version" ]; then
		# Determine architecture
		local arch="$(uname -m)"
		[ "$arch" = "x86_64" ] && arch="amd64"
		[ "$arch" = "aarch64" ] && arch="arm64"

		# Download and install Go
		local tmp_archive="/tmp/go.tar.gz"
		info "Downloading Go ${version} for ${arch}..."
		curl -L "https://go.dev/dl/go${version}.linux-${arch}.tar.gz" -o "$tmp_archive"

		if [ ! -f "$tmp_archive" ]; then
			error "Failed to download Go archive"
		fi

		# Clean directory if it exists
		if [ -d "$go_dir" ]; then
			info "Removing existing Go installation..."
			sudo rm -rf "$go_dir"
		fi

		# Create parent directory if needed
		sudo mkdir -p "$(dirname "$go_dir")"
		sudo chown root:staff "$(dirname "$go_dir")"
		sudo chmod 775 "$(dirname "$go_dir")"

		# Extract archive with proper permissions
		info "Extracting Go archive..."
		sudo tar -C "$(dirname "$go_dir")" -xzf "$tmp_archive"
		rm -f "$tmp_archive"

		# Set permissions
		ensure_dir_permissions "$go_dir" "775" true

		# Create symlinks
		if [ -f "$go_dir/bin/go" ]; then
			create_managed_symlink "$go_dir/bin/go" "$BASE_DIR/bin/go"
		else
			warn "Go binary not found at $go_dir/bin/go"
		fi

		if [ -f "$go_dir/bin/gofmt" ]; then
			create_managed_symlink "$go_dir/bin/gofmt" "$BASE_DIR/bin/gofmt"
		else
			warn "Gofmt binary not found at $go_dir/bin/gofmt"
		fi

		# Verify installation
		if [ -f "$go_dir/bin/go" ]; then
			TOOLCHAIN_STATES["go"]="installed"
			TOOLCHAIN_VERSIONS["go"]="$version"
		else
			TOOLCHAIN_STATES["go"]="failed"
			TOOLCHAIN_VERSIONS["go"]="unknown"
			warn "Go installation may not have completed successfully"
		fi
	else
		TOOLCHAIN_STATES["go"]="current"
		TOOLCHAIN_VERSIONS["go"]="$version"
	fi
}

###############################################################################
# Zig Management
###############################################################################

install_zig() {
	local zig_dir="$BASE_DIR/share/dev/toolchains/zig"

	info "Processing Zig toolchain..."

	# Safely get current version if Zig is installed
	local current_version=""
	if command -v zig >/dev/null 2>&1; then
		current_version=$(zig version 2>/dev/null || echo "")
	fi

	# Get latest version with error handling
	local version=""
	local version_json=$(curl -s https://ziglang.org/download/index.json || echo '{}')
	if [ -n "$version_json" ] && [ "$version_json" != "{}" ]; then
		version=$(echo "$version_json" | grep -o '"version": "[0-9.]*"' | head -1 | grep -o '[0-9.]*' || echo "")
	fi

	if [ -z "$version" ]; then
		warn "Could not determine latest Zig version. Using fallback version 0.11.0"
		version="0.11.0"
	fi

	# Determine if we need to install or update
	if [ ! -d "$zig_dir" ] || [ -z "$current_version" ] || [ "$current_version" != "$version" ]; then
		# Determine architecture
		local arch="$(uname -m)"
		[ "$arch" = "x86_64" ] && arch="x86_64"
		[ "$arch" = "aarch64" ] && arch="aarch64"

		# Download and install Zig
		local tmp_archive="/tmp/zig.tar.xz"
		info "Downloading Zig ${version} for ${arch}..."
		curl -L "https://ziglang.org/download/$version/zig-linux-${arch}-$version.tar.xz" -o "$tmp_archive"

		if [ ! -f "$tmp_archive" ]; then
			error "Failed to download Zig archive"
		fi

		# Clean directory if it exists
		if [ -d "$zig_dir" ]; then
			info "Removing existing Zig installation..."
			sudo rm -rf "$zig_dir"
		fi

		# Create parent directory with proper permissions
		sudo mkdir -p "$zig_dir"
		sudo chown root:staff "$zig_dir"
		sudo chmod 775 "$zig_dir"

		# Extract archive with proper permissions
		info "Extracting Zig archive..."
		sudo tar -C "$zig_dir" --strip-components=1 -xJf "$tmp_archive"
		rm -f "$tmp_archive"

		# Set permissions
		ensure_dir_permissions "$zig_dir" "775" true

		# Create symlink
		if [ -f "$zig_dir/zig" ]; then
			create_managed_symlink "$zig_dir/zig" "$BASE_DIR/bin/zig"
		else
			warn "Zig binary not found at $zig_dir/zig"
		fi

		# Verify installation
		if [ -f "$zig_dir/zig" ]; then
			TOOLCHAIN_STATES["zig"]="installed"
			TOOLCHAIN_VERSIONS["zig"]="$version"
		else
			TOOLCHAIN_STATES["zig"]="failed"
			TOOLCHAIN_VERSIONS["zig"]="unknown"
			warn "Zig installation may not have completed successfully"
		fi
	else
		TOOLCHAIN_STATES["zig"]="current"
		TOOLCHAIN_VERSIONS["zig"]="$version"
	fi
}

###############################################################################
# Perl Management
###############################################################################

install_perl() {
	local perl_dir="$BASE_DIR/share/dev/toolchains/perl"
	local target_version="5.38.0" # Fixed version

	info "Processing Perl toolchain..."

	# Check if Perl is already installed in our managed directory
	if [ -f "$perl_dir/bin/perl" ]; then
		local current_version
		current_version=$("$perl_dir/bin/perl" -v 2>/dev/null | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | sed 's/v//' | head -1)

		info "Found existing Perl installation: version $current_version"

		if [ "$current_version" = "$target_version" ]; then
			info "Perl $target_version is already installed, skipping..."
			TOOLCHAIN_STATES["perl"]="current"
			TOOLCHAIN_VERSIONS["perl"]="$target_version"
			return 0
		else
			info "Upgrading Perl from $current_version to $target_version"
		fi
	else
		info "No existing Perl installation found in $perl_dir"
	fi

	# Continue with installation...
	# Rest of installation logic
}

###############################################################################
# Summary Report
###############################################################################

print_summary() {
	echo
	echo "Toolchain Installation Summary:"
	echo "------------------------------"
	for toolchain in "${!TOOLCHAIN_STATES[@]}"; do
		printf "%-10s: %-10s (version: %s)\n" \
			"$toolchain" \
			"${TOOLCHAIN_STATES[$toolchain]}" \
			"${TOOLCHAIN_VERSIONS[$toolchain]}"
	done
	echo "------------------------------"
}

###############################################################################
# Main Process
###############################################################################

main() {
	info "Starting toolchain installations..."

	# Set up directory structure
	setup_toolchain_dirs

	# Install toolchains - use || true to continue even if one fails
	install_miniconda || {
		warn "Miniconda installation failed, continuing..."
		true
	}
	install_rust || {
		warn "Rust installation failed, continuing..."
		true
	}
	install_go || {
		warn "Go installation failed, continuing..."
		true
	}
	install_zig || {
		warn "Zig installation failed, continuing..."
		true
	}
	install_perl || {
		warn "Perl installation failed, continuing..."
		true
	}

	# Print installation summary
	print_summary
}

# Execute main function
main "$@"
