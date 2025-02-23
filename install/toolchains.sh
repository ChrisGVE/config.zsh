#!/usr/bin/env bash

###############################################################################
# Development Toolchains Management Script
#
# Purpose:
# This script manages the installation and updating of core development toolchains:
# - Python (via Miniconda)
# - Rust (via rustup)
# - Go
# - Zig
# - Perl
#
# Each toolchain is installed in a consistent location and properly symlinked.
# The script ensures:
# - Consistent installation paths
# - Latest stable versions
# - Proper permissions for multi-user access
# - Correct symlink management
###############################################################################

set -euo pipefail

# Print status messages
info() { echo "[INFO] $1" >&2; }
warn() { echo "[WARN] $1" >&2; }
error() {
	echo "[ERROR] $1"
	exit 1
}

###############################################################################
# Environment Setup
###############################################################################

# Setup directories for toolchain installation
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
# Version Management
###############################################################################

# Get latest version from GitHub releases
get_latest_github_version() {
	local repo="$1"
	local prefix="${2:-v}"
	curl -s "https://api.github.com/repos/$repo/releases/latest" |
		grep "tag_name" |
		cut -d'"' -f4 |
		sed "s/^$prefix//"
}

###############################################################################
# Python/Conda Management
###############################################################################

install_miniconda() {
	local base_dir="$1"
	local conda_dir="$base_dir/conda"
	local conda_bin="$conda_dir/bin/conda"

	if [ ! -f "$conda_bin" ]; then
		info "Installing Miniconda..."
		local installer="/tmp/miniconda.sh"
		curl -L "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-$(uname -m).sh" -o "$installer"
		sudo bash "$installer" -b -p "$conda_dir"
		rm -f "$installer"

		# Set permissions for multi-user access
		sudo chmod -R 775 "$conda_dir"
		sudo chown -R root:staff "$conda_dir"
	else
		info "Updating Conda installation..."
		sudo "$conda_bin" update -n base -c defaults conda -y
	fi

	# Ensure conda is in PATH via symlink
	sudo ln -sf "$conda_bin" "$base_dir/bin/conda"
}

###############################################################################
# Rust Management
###############################################################################

install_rust() {
	local base_dir="$1"
	local rust_dir="$base_dir/rust"

	if ! command -v rustup >/dev/null 2>&1; then
		info "Installing Rust toolchain..."
		sudo mkdir -p "$rust_dir"
		# Download and run rustup-init with custom settings
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
			sudo RUSTUP_HOME="$rust_dir/rustup" CARGO_HOME="$rust_dir/cargo" sh -s -- -y --no-modify-path

		# Set permissions
		sudo chmod -R 775 "$rust_dir"
		sudo chown -R root:staff "$rust_dir"
	else
		info "Updating Rust toolchain..."
		sudo RUSTUP_HOME="$rust_dir/rustup" CARGO_HOME="$rust_dir/cargo" rustup update
	fi

	# Create symlinks
	sudo ln -sf "$rust_dir/cargo/bin/cargo" "$base_dir/bin/cargo"
	sudo ln -sf "$rust_dir/cargo/bin/rustc" "$base_dir/bin/rustc"
	sudo ln -sf "$rust_dir/cargo/bin/rustup" "$base_dir/bin/rustup"
}

###############################################################################
# Go Management
###############################################################################

install_go() {
	local base_dir="$1"
	local go_dir="$base_dir/go"
	local version=$(curl -s https://go.dev/dl/?mode=json | grep -o '"version": "go[0-9.]*"' | head -1 | grep -o '[0-9.]*')

	if [ ! -d "$go_dir" ] || [ "$(go version 2>/dev/null | grep -o 'go[0-9.]*' | grep -o '[0-9.]*')" != "$version" ]; then
		info "Installing/Updating Go to version $version..."
		local arch="$(uname -m)"
		[ "$arch" = "x86_64" ] && arch="amd64"
		[ "$arch" = "aarch64" ] && arch="arm64"

		local tmp_file="/tmp/go.tar.gz"
		curl -L "https://go.dev/dl/go${version}.linux-${arch}.tar.gz" -o "$tmp_file"
		sudo rm -rf "$go_dir"
		sudo tar -C "$base_dir" -xzf "$tmp_file"
		rm -f "$tmp_file"

		# Set permissions
		sudo chmod -R 775 "$go_dir"
		sudo chown -R root:staff "$go_dir"
	else
		info "Go is already at latest version $version"
	fi

	# Ensure Go binaries are in PATH
	sudo ln -sf "$go_dir/bin/go" "$base_dir/bin/go"
	sudo ln -sf "$go_dir/bin/gofmt" "$base_dir/bin/gofmt"
}

###############################################################################
# Zig Management
###############################################################################

install_zig() {
	local base_dir="$1"
	local zig_dir="$base_dir/zig"
	local version=$(get_latest_github_version "ziglang/zig")

	if [ ! -d "$zig_dir" ] || [ "$(zig version 2>/dev/null)" != "$version" ]; then
		info "Installing/Updating Zig to version $version..."
		local arch="$(uname -m)"
		[ "$arch" = "x86_64" ] && arch="x86_64"
		[ "$arch" = "aarch64" ] && arch="aarch64"

		local tmp_file="/tmp/zig.tar.xz"
		curl -L "https://ziglang.org/download/$version/zig-linux-${arch}-$version.tar.xz" -o "$tmp_file"
		sudo rm -rf "$zig_dir"
		sudo mkdir -p "$zig_dir"
		sudo tar -C "$zig_dir" --strip-components=1 -xJf "$tmp_file"
		rm -f "$tmp_file"

		# Set permissions
		sudo chmod -R 775 "$zig_dir"
		sudo chown -R root:staff "$zig_dir"
	else
		info "Zig is already at latest version $version"
	fi

	# Create symlink
	sudo ln -sf "$zig_dir/zig" "$base_dir/bin/zig"
}

###############################################################################
# Perl Management
###############################################################################

install_perl() {
	local base_dir="$1"
	local perl_dir="$base_dir/perl"
	local version=$(curl -s https://www.perl.org/get.html | grep -o 'perl-[0-9.]*\.tar\.gz' | head -1 | grep -o '[0-9.]*')

	if [ ! -d "$perl_dir" ] || [ "$(perl -v | grep -o '[0-9.]*' | head -1)" != "$version" ]; then
		info "Installing/Updating Perl to version $version..."
		local tmp_dir="/tmp/perl-build"
		local tmp_file="$tmp_dir/perl.tar.gz"

		mkdir -p "$tmp_dir"
		curl -L "https://www.cpan.org/src/5.0/perl-$version.tar.gz" -o "$tmp_file"
		cd "$tmp_dir"
		tar xzf "$tmp_file"
		cd "perl-$version"

		# Configure and build
		sudo ./Configure -des -Dprefix="$perl_dir"
		sudo make
		sudo make install

		# Cleanup
		cd
		rm -rf "$tmp_dir"

		# Set permissions
		sudo chmod -R 775 "$perl_dir"
		sudo chown -R root:staff "$perl_dir"
	else
		info "Perl is already at latest version $version"
	fi

	# Create symlinks
	sudo ln -sf "$perl_dir/bin/perl" "$base_dir/bin/perl"
	sudo ln -sf "$perl_dir/bin/cpan" "$base_dir/bin/cpan"
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	if [ $# -ne 1 ]; then
		error "Usage: $0 <install_base_dir>"
	fi

	local base_dir="$1"
	info "Using installation base directory: $base_dir"

	# Verify the directory exists
	if [ ! -d "$base_dir" ]; then
		error "Installation base directory does not exist: $base_dir"
	fi

	# Setup directory structure
	setup_dirs "$base_dir"

	# Install all toolchains
	install_miniconda "$base_dir"
	install_rust "$base_dir"
	install_go "$base_dir"
	install_zig "$base_dir"
	install_perl "$base_dir"

	info "All toolchains installed/updated successfully"
}
