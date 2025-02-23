#!/usr/bin/env bash

###############################################################################
# Development Toolchains Management Script
#
# Purpose:
# This script manages core development toolchains in a multi-user environment.
# It handles installation, updates, and consistent configuration of:
# - Python (via Miniconda3)
# - Rust (via rustup)
# - Go
# - Zig
# - Perl
#
# Features:
# - Consistent installation paths under /opt/local or /usr/local
# - Latest stable versions by default with option for HEAD
# - Multi-user access with appropriate permissions
# - Version tracking and smart updates
# - Symlink management for PATH access
#
# Usage:
# toolchains.sh <install_base_dir> [--force]
#   install_base_dir: Base directory for installations (/opt/local or /usr/local)
#   --force: Optional flag to force rebuild/reinstall of all toolchains
#
# Installation Process per Toolchain:
# 1. Version check (current vs latest available)
# 2. Download and verification
# 3. Installation with multi-user permissions
# 4. PATH management via symlinks
# 5. Environment configuration
#
# Each toolchain installation includes:
# - Binary installation in <base_dir>/<toolchain>
# - Symlinks in <base_dir>/bin
# - Shared permissions (775) for multi-user access
# - Version tracking for update management
###############################################################################

set -euo pipefail

# Status message functions
info() { echo "[INFO] Toolchains: $1" >&2; }
warn() { echo "[WARN] Toolchains: $1" >&2; }
error() {
	echo "[ERROR] Toolchains: $1"
	exit 1
}

# Track toolchain states for summary
declare -A TOOLCHAIN_STATES
declare -A TOOLCHAIN_VERSIONS

###############################################################################
# Directory Management
###############################################################################

# Setup directories for toolchain installation
# Args:
#   $1: Base installation directory
setup_dirs() {
	local base_dir="$1"
	local dirs=(
		"$base_dir/bin"
		"$base_dir/share"
		"$base_dir/lib"
		"$base_dir/include"
	)

	for dir in "${dirs[@]}"; do
		if [ ! -d "$dir" ]; then
			sudo mkdir -p "$dir"
			sudo chmod 775 "$dir"
		fi
	done
}

###############################################################################
# Python/Conda Management
###############################################################################

install_miniconda() {
	local base_dir="$1"
	local force="$2"
	local conda_dir="$base_dir/conda"
	local conda_bin="$conda_dir/bin/conda"
	local version_info="/tmp/conda_version.txt"

	info "Processing Miniconda installation..."

	# Check for force update or missing installation
	if [ "$force" = "true" ] || [ ! -f "$conda_bin" ]; then
		curl -L "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(uname -m).sh" -o "/tmp/miniconda.sh"
		sudo bash "/tmp/miniconda.sh" -b -p "$conda_dir"
		rm -f "/tmp/miniconda.sh"

		sudo chmod -R 775 "$conda_dir"
		sudo chown -R root:staff "$conda_dir"
		sudo ln -sf "$conda_bin" "$base_dir/bin/conda"

		"$conda_bin" --version >"$version_info"
		TOOLCHAIN_STATES["conda"]="installed"
		TOOLCHAIN_VERSIONS["conda"]=$(cat "$version_info")
	else
		"$conda_bin" update -n base -c defaults conda -y
		"$conda_bin" --version >"$version_info"
		TOOLCHAIN_STATES["conda"]="updated"
		TOOLCHAIN_VERSIONS["conda"]=$(cat "$version_info")
	fi
}

###############################################################################
# Rust Management
###############################################################################

install_rust() {
	local base_dir="$1"
	local force="$2"
	local rust_dir="$base_dir/rust"

	info "Processing Rust toolchain..."

	if [ "$force" = "true" ] || ! command -v rustup >/dev/null 2>&1; then
		sudo mkdir -p "$rust_dir"
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
			sudo RUSTUP_HOME="$rust_dir/rustup" CARGO_HOME="$rust_dir/cargo" sh -s -- -y --no-modify-path

		sudo chmod -R 775 "$rust_dir"
		sudo chown -R root:staff "$rust_dir"

		# Create symlinks
		sudo ln -sf "$rust_dir/cargo/bin/cargo" "$base_dir/bin/cargo"
		sudo ln -sf "$rust_dir/cargo/bin/rustc" "$base_dir/bin/rustc"
		sudo ln -sf "$rust_dir/cargo/bin/rustup" "$base_dir/bin/rustup"

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
	local base_dir="$1"
	local force="$2"
	local go_dir="$base_dir/go"
	local version=$(curl -s https://go.dev/dl/?mode=json | grep -o '"version": "go[0-9.]*"' | head -1 | grep -o '[0-9.]*')

	info "Processing Go toolchain..."

	if [ "$force" = "true" ] || [ ! -d "$go_dir" ] || [ "$(go version 2>/dev/null | grep -o 'go[0-9.]*' | grep -o '[0-9.]*')" != "$version" ]; then
		local arch="$(uname -m)"
		[ "$arch" = "x86_64" ] && arch="amd64"
		[ "$arch" = "aarch64" ] && arch="arm64"

		curl -L "https://go.dev/dl/go${version}.linux-${arch}.tar.gz" -o "/tmp/go.tar.gz"
		sudo rm -rf "$go_dir"
		sudo tar -C "$base_dir" -xzf "/tmp/go.tar.gz"
		rm -f "/tmp/go.tar.gz"

		sudo chmod -R 775 "$go_dir"
		sudo chown -R root:staff "$go_dir"

		sudo ln -sf "$go_dir/bin/go" "$base_dir/bin/go"
		sudo ln -sf "$go_dir/bin/gofmt" "$base_dir/bin/gofmt"

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
	local base_dir="$1"
	local force="$2"
	local zig_dir="$base_dir/zig"
	local version=$(curl -s https://ziglang.org/download/index.json | grep -o '"version": "[0-9.]*"' | head -1 | grep -o '[0-9.]*')

	info "Processing Zig toolchain..."

	if [ "$force" = "true" ] || [ ! -d "$zig_dir" ] || [ "$(zig version 2>/dev/null)" != "$version" ]; then
		local arch="$(uname -m)"
		[ "$arch" = "x86_64" ] && arch="x86_64"
		[ "$arch" = "aarch64" ] && arch="aarch64"

		curl -L "https://ziglang.org/download/$version/zig-linux-${arch}-$version.tar.xz" -o "/tmp/zig.tar.xz"
		sudo rm -rf "$zig_dir"
		sudo mkdir -p "$zig_dir"
		sudo tar -C "$zig_dir" --strip-components=1 -xJf "/tmp/zig.tar.xz"
		rm -f "/tmp/zig.tar.xz"

		sudo chmod -R 775 "$zig_dir"
		sudo chown -R root:staff "$zig_dir"
		sudo ln -sf "$zig_dir/zig" "$base_dir/bin/zig"

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
	local base_dir="$1"
	local force="$2"
	local perl_dir="$base_dir/perl"
	local version=$(curl -s https://www.perl.org/get.html | grep -o 'perl-[0-9.]*\.tar\.gz' | head -1 | grep -o '[0-9.]*')

	info "Processing Perl toolchain..."

	if [ "$force" = "true" ] || [ ! -d "$perl_dir" ] || [ "$(perl -v | grep -o '[0-9.]*' | head -1)" != "$version" ]; then
		local tmp_dir="/tmp/perl-build"
		mkdir -p "$tmp_dir"
		curl -L "https://www.cpan.org/src/5.0/perl-$version.tar.gz" -o "$tmp_dir/perl.tar.gz"
		cd "$tmp_dir"
		tar xzf "perl.tar.gz"
		cd "perl-$version"

		sudo ./Configure -des -Dprefix="$perl_dir"
		sudo make
		sudo make install

		cd
		rm -rf "$tmp_dir"

		sudo chmod -R 775 "$perl_dir"
		sudo chown -R root:staff "$perl_dir"
		sudo ln -sf "$perl_dir/bin/perl" "$base_dir/bin/perl"
		sudo ln -sf "$perl_dir/bin/cpan" "$base_dir/bin/cpan"

		TOOLCHAIN_STATES["perl"]="installed"
		TOOLCHAIN_VERSIONS["perl"]="$version"
	else
		TOOLCHAIN_STATES["perl"]="current"
		TOOLCHAIN_VERSIONS["perl"]="$version"
	fi
}

###############################################################################
# Status Summary
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
	if [ $# -lt 1 ]; then
		error "Usage: $0 <install_base_dir> [--force]"
	fi

	local base_dir="$1"
	local force="false"

	if [ $# -eq 2 ] && [ "$2" = "--force" ]; then
		force="true"
		info "Force update mode enabled"
	fi

	info "Using installation base directory: $base_dir"

	# Setup directory structure
	setup_dirs "$base_dir"

	# Install all toolchains
	install_miniconda "$base_dir" "$force"
	install_rust "$base_dir" "$force"
	install_go "$base_dir" "$force"
	install_zig "$base_dir" "$force"
	install_perl "$base_dir" "$force"

	# Print summary
	print_summary
}

# Execute main function
main "$@"
