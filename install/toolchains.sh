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
		local tmp_installer="/tmp/miniconda.sh"
		curl -L "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(uname -m).sh" -o "$tmp_installer"

		sudo bash "$tmp_installer" -b -p "$conda_dir"
		rm -f "$tmp_installer"

		# Set permissions
		ensure_dir_permissions "$conda_dir" "775" true

		# Create symlinks
		create_managed_symlink "$conda_bin" "$BASE_DIR/bin/conda"
		create_managed_symlink "$conda_dir/bin/python" "$BASE_DIR/bin/python3"

		TOOLCHAIN_STATES["conda"]="installed"
		TOOLCHAIN_VERSIONS["conda"]=$("$conda_bin" --version | cut -d' ' -f2)
	else
		"$conda_bin" update -n base -c defaults conda -y
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

	if ! command -v rustup >/dev/null 2>&1; then
		# Create initial required directories
		ensure_dir_permissions "$rust_dir/rustup"
		ensure_dir_permissions "$rust_dir/cargo"

		# Download and run rustup-init with proper permissions
		local tmp_installer="/tmp/rustup-init.sh"
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "$tmp_installer"

		# Initialize Rust installation
		sudo -E env \
			"RUSTUP_HOME=$rust_dir/rustup" \
			"CARGO_HOME=$rust_dir/cargo" \
			bash "$tmp_installer" -y --no-modify-path

		rm -f "$tmp_installer"

		# Fix permissions
		ensure_dir_permissions "$rust_dir" "775" true

		# Create symlinks
		create_managed_symlink "$rust_dir/cargo/bin/cargo" "$BASE_DIR/bin/cargo"
		create_managed_symlink "$rust_dir/cargo/bin/rustc" "$BASE_DIR/bin/rustc"
		create_managed_symlink "$rust_dir/cargo/bin/rustup" "$BASE_DIR/bin/rustup"

		TOOLCHAIN_STATES["rust"]="installed"
		TOOLCHAIN_VERSIONS["rust"]=$("$rust_dir/cargo/bin/rustc" --version | cut -d' ' -f2)
	else
		RUSTUP_HOME="$rust_dir/rustup" CARGO_HOME="$rust_dir/cargo" rustup update
		TOOLCHAIN_STATES["rust"]="updated"
		TOOLCHAIN_VERSIONS["rust"]=$(rustc --version | cut -d' ' -f2)
	fi
}

###############################################################################
# Go Management
###############################################################################

install_go() {
	local go_dir="$BASE_DIR/share/dev/toolchains/go"

	info "Processing Go toolchain..."

	# Get latest version
	local version=$(curl -s https://go.dev/dl/?mode=json |
		grep -o '"version": "go[0-9.]*"' | head -1 |
		grep -o '[0-9.]*')

	if [ ! -d "$go_dir" ] ||
		[ "$(go version 2>/dev/null | grep -o 'go[0-9.]*' | grep -o '[0-9.]*')" != "$version" ]; then

		local arch="$(uname -m)"
		[ "$arch" = "x86_64" ] && arch="amd64"
		[ "$arch" = "aarch64" ] && arch="arm64"

		# Download and install Go
		local tmp_archive="/tmp/go.tar.gz"
		curl -L "https://go.dev/dl/go${version}.linux-${arch}.tar.gz" -o "$tmp_archive"

		sudo rm -rf "$go_dir"
		sudo tar -C "$(dirname "$go_dir")" -xzf "$tmp_archive"
		rm -f "$tmp_archive"

		# Set permissions
		ensure_dir_permissions "$go_dir" "775" true

		# Create symlinks
		create_managed_symlink "$go_dir/bin/go" "$BASE_DIR/bin/go"
		create_managed_symlink "$go_dir/bin/gofmt" "$BASE_DIR/bin/gofmt"

		TOOLCHAIN_STATES["go"]="installed"
		TOOLCHAIN_VERSIONS["go"]="$version"
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

	# Get latest version
	local version=$(curl -s https://ziglang.org/download/index.json |
		grep -o '"version": "[0-9.]*"' | head -1 |
		grep -o '[0-9.]*')

	if [ ! -d "$zig_dir" ] || [ "$(zig version 2>/dev/null)" != "$version" ]; then
		local arch="$(uname -m)"
		[ "$arch" = "x86_64" ] && arch="x86_64"
		[ "$arch" = "aarch64" ] && arch="aarch64"

		# Download and install Zig
		local tmp_archive="/tmp/zig.tar.xz"
		curl -L "https://ziglang.org/download/$version/zig-linux-${arch}-$version.tar.xz" -o "$tmp_archive"

		sudo rm -rf "$zig_dir"
		sudo mkdir -p "$zig_dir"
		sudo tar -C "$zig_dir" --strip-components=1 -xJf "$tmp_archive"
		rm -f "$tmp_archive"

		# Set permissions
		ensure_dir_permissions "$zig_dir" "775" true

		# Create symlink
		create_managed_symlink "$zig_dir/zig" "$BASE_DIR/bin/zig"

		TOOLCHAIN_STATES["zig"]="installed"
		TOOLCHAIN_VERSIONS["zig"]="$version"
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

	info "Processing Perl toolchain..."

	# Get latest version
	local version=$(curl -s https://www.perl.org/get.html |
		grep -o 'perl-[0-9.]*\.tar\.gz' | head -1 |
		grep -o '[0-9.]*')

	if [ ! -d "$perl_dir" ] || [ "$(perl -v | grep -o '[0-9.]*' | head -1)" != "$version" ]; then
		local tmp_dir="/tmp/perl-build"
		mkdir -p "$tmp_dir"

		# Download and extract Perl
		curl -L "https://www.cpan.org/src/5.0/perl-$version.tar.gz" -o "$tmp_dir/perl.tar.gz"
		cd "$tmp_dir"
		tar xzf "perl.tar.gz"
		cd "perl-$version"

		# Configure and build
		sudo ./Configure -des -Dprefix="$perl_dir"
		sudo make
		sudo make install

		cd
		rm -rf "$tmp_dir"

		# Set permissions
		ensure_dir_permissions "$perl_dir" "775" true

		# Create symlinks
		create_managed_symlink "$perl_dir/bin/perl" "$BASE_DIR/bin/perl"
		create_managed_symlink "$perl_dir/bin/cpan" "$BASE_DIR/bin/cpan"

		TOOLCHAIN_STATES["perl"]="installed"
		TOOLCHAIN_VERSIONS["perl"]="$version"
	else
		TOOLCHAIN_STATES["perl"]="current"
		TOOLCHAIN_VERSIONS["perl"]="$version"
	fi
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

	# Install all toolchains
	install_miniconda
	install_rust
	install_go
	install_zig
	install_perl

	# Print installation summary
	print_summary
}

# Execute main function
main "$@"
