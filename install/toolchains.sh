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
# - Platform-appropriate permissions
# - Version tracking
# - Proper PATH management via symlinks
###############################################################################

set -euo pipefail

# Source common functions
source "$(dirname "$0")/common.sh" || {
	echo "Error: Failed to source common.sh"
	exit 1
}

# Track toolchain states for summary
declare -A TOOLCHAIN_STATES
declare -A TOOLCHAIN_VERSIONS

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
		"$toolchains_dir/ruby"
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
			# Make sure to completely remove the directory with proper permissions
			sudo rm -rf "$conda_dir"
			# Verify removal was successful
			if [ -d "$conda_dir" ]; then
				error "Failed to remove existing conda directory. Please remove it manually: sudo rm -rf $conda_dir"
			fi
		fi

		# Create directory with proper permissions
		sudo mkdir -p "$conda_dir"
		sudo chown root:$ADMIN_GROUP "$conda_dir"
		sudo chmod 775 "$conda_dir"

		# Determine architecture and OS
		local arch=$(uname -m)
		local os_name="Linux"
		if [ "$OS_TYPE" = "macos" ]; then
			os_name="MacOSX"
		fi

		# Download installer
		local tmp_installer="/tmp/miniconda.sh"
		curl -L "https://repo.anaconda.com/miniconda/Miniconda3-latest-${os_name}-${arch}.sh" -o "$tmp_installer"

		# Run installer with sudo to avoid permission issues
		# Add -f to force the installation in the specified directory
		sudo bash "$tmp_installer" -b -f -p "$conda_dir"
		local install_status=$?
		rm -f "$tmp_installer"

		# Check if installation was successful
		if [ $install_status -ne 0 ] || [ ! -f "$conda_bin" ]; then
			error "Miniconda installation failed. Binary not found at $conda_bin"
		fi

		# Set permissions
		ensure_dir_permissions "$conda_dir" "775" "true"

		# Create symlinks
		create_managed_symlink "$conda_bin" "$BASE_DIR/bin/conda"
		create_managed_symlink "$conda_dir/bin/python" "$BASE_DIR/bin/python3"

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
	sudo chown -R root:$ADMIN_GROUP "$rust_dir"
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
			sudo chown -R root:$ADMIN_GROUP "$rust_dir"
			sudo chmod -R 775 "$rust_dir"
		fi

		# Initialize Rust installation with correct permissions
		info "Running rustup installer..."
		(cd /tmp &&
			sudo -E env \
				RUSTUP_HOME="$rust_dir/rustup" \
				CARGO_HOME="$rust_dir/cargo" \
				bash "$tmp_installer" -y --no-modify-path --default-toolchain stable)

		rm -f "$tmp_installer"

		# Fix permissions again after installation
		sudo chown -R root:$ADMIN_GROUP "$rust_dir"
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
		rust_version=$(RUSTUP_HOME="$rust_dir/rustup" CARGO_HOME="$rust_dir/cargo" "$rust_dir/cargo/bin/rustc" --version | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+" || echo "unknown")

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
		warn "Could not determine latest Go version. Using fallback version 1.22.0"
		version="1.22.0"
	fi

	# Determine if we need to install or update
	if [ ! -d "$go_dir" ] || [ -z "$current_version" ] || [ "$current_version" != "$version" ]; then
		# Determine architecture and OS
		local arch="$(uname -m)"
		local os="linux"

		if [ "$OS_TYPE" = "macos" ]; then
			os="darwin"
		fi

		[ "$arch" = "x86_64" ] && arch="amd64"
		[ "$arch" = "aarch64" ] && arch="arm64"

		# Download and install Go
		local tmp_archive="/tmp/go.tar.gz"
		info "Downloading Go ${version} for ${os}-${arch}..."
		curl -L "https://go.dev/dl/go${version}.${os}-${arch}.tar.gz" -o "$tmp_archive"

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
		sudo chown root:$ADMIN_GROUP "$(dirname "$go_dir")"
		sudo chmod 775 "$(dirname "$go_dir")"

		# Extract archive with proper permissions
		info "Extracting Go archive..."
		sudo tar -C "$(dirname "$go_dir")" -xzf "$tmp_archive"
		rm -f "$tmp_archive"

		# Set permissions
		ensure_dir_permissions "$go_dir" "775" "true"

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
		# Determine architecture and OS
		local arch="$(uname -m)"
		local os="linux"

		if [ "$OS_TYPE" = "macos" ]; then
			os="macos"
		fi

		[ "$arch" = "x86_64" ] && arch="x86_64"
		[ "$arch" = "aarch64" ] && arch="aarch64"

		# Download and install Zig
		local tmp_archive="/tmp/zig.tar.xz"
		info "Downloading Zig ${version} for ${os}-${arch}..."
		curl -L "https://ziglang.org/download/$version/zig-${os}-${arch}-$version.tar.xz" -o "$tmp_archive"

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
		sudo chown root:$ADMIN_GROUP "$zig_dir"
		sudo chmod 775 "$zig_dir"

		# Extract archive with proper permissions
		info "Extracting Zig archive..."
		sudo tar -C "$zig_dir" --strip-components=1 -xJf "$tmp_archive"
		rm -f "$tmp_archive"

		# Set permissions
		ensure_dir_permissions "$zig_dir" "775" "true"

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

	# For Perl, we'll prefer to use the system's package manager when available
	# It's complex to build from source and has many dependencies
	if [ "$OS_TYPE" = "macos" ] && command -v brew >/dev/null 2>&1; then
		info "Installing Perl via Homebrew on macOS"
		brew install perl

		# Create symlink to system Perl
		if command -v perl >/dev/null 2>&1; then
			local perl_path=$(command -v perl)
			sudo mkdir -p "$perl_dir/bin"
			create_managed_symlink "$perl_path" "$BASE_DIR/bin/perl"
			TOOLCHAIN_STATES["perl"]="installed"
			TOOLCHAIN_VERSIONS["perl"]=$(perl -e 'print $^V' | sed 's/v//')
		else
			TOOLCHAIN_STATES["perl"]="failed"
			TOOLCHAIN_VERSIONS["perl"]="unknown"
		fi
	else
		# On Linux systems, use the package manager
		case "$PACKAGE_MANAGER" in
		apt)
			info "Installing Perl via apt"
			sudo apt-get update
			sudo apt-get install -y perl perl-modules
			;;
		dnf)
			info "Installing Perl via dnf"
			sudo dnf install -y perl perl-libs
			;;
		pacman)
			info "Installing Perl via pacman"
			sudo pacman -Sy --noconfirm perl
			;;
		*)
			warn "Unsupported package manager for Perl installation"
			TOOLCHAIN_STATES["perl"]="skipped"
			TOOLCHAIN_VERSIONS["perl"]="unknown"
			return 0
			;;
		esac

		# Create symlink to system Perl
		if command -v perl >/dev/null 2>&1; then
			local perl_path=$(command -v perl)
			sudo mkdir -p "$perl_dir/bin"
			create_managed_symlink "$perl_path" "$BASE_DIR/bin/perl"
			TOOLCHAIN_STATES["perl"]="installed"
			TOOLCHAIN_VERSIONS["perl"]=$(perl -e 'print $^V' | sed 's/v//')
		else
			TOOLCHAIN_STATES["perl"]="failed"
			TOOLCHAIN_VERSIONS["perl"]="unknown"
		fi
	fi
}

###############################################################################
# Ruby Management
###############################################################################

install_ruby() {
	local ruby_dir="$BASE_DIR/share/dev/toolchains/ruby"

	info "Processing Ruby toolchain..."

	# Detect the desired Ruby version - use a more recent version
	local target_version="3.4.2" # Latest stable version

	# Check if we already have Ruby installed from source at the target version
	if [ -f "$ruby_dir/bin/ruby" ]; then
		local installed_version=$("$ruby_dir/bin/ruby" -e 'puts RUBY_VERSION' 2>/dev/null || echo "")

		if [ "$installed_version" = "$target_version" ]; then
			info "Ruby $target_version is already installed at $ruby_dir"
			TOOLCHAIN_STATES["ruby"]="current"
			TOOLCHAIN_VERSIONS["ruby"]="$target_version"
			return 0
		else
			info "Upgrading Ruby from $installed_version to $target_version"
		fi
	fi

	# Always prefer source installation for Ruby to get the latest version
	info "Installing Ruby $target_version from source..."
	install_ruby_from_source "$ruby_dir" "$target_version"
}

# Function to install Ruby from source
install_ruby_from_source() {
	local ruby_dir="$1"
	local target_version="$2"
	local tmp_dir=$(mktemp -d)

	info "Installing Ruby $target_version from source..."

	# Install build dependencies first
	case "$PACKAGE_MANAGER" in
	brew)
		brew install openssl readline
		;;
	apt)
		sudo apt-get update
		sudo apt-get install -y build-essential libssl-dev libreadline-dev zlib1g-dev
		;;
	dnf)
		sudo dnf install -y gcc make openssl-devel readline-devel zlib-devel
		;;
	pacman)
		sudo pacman -Sy --noconfirm base-devel openssl readline zlib
		;;
	esac

	# Download Ruby source
	curl -L "https://cache.ruby-lang.org/pub/ruby/${target_version%.*}/ruby-${target_version}.tar.gz" -o "$tmp_dir/ruby.tar.gz"

	# Make sure previous installation is cleaned up
	sudo rm -rf "$ruby_dir"
	sudo mkdir -p "$ruby_dir"
	sudo chown root:$ADMIN_GROUP "$ruby_dir"
	sudo chmod 775 "$ruby_dir"

	# Extract and build
	cd "$tmp_dir" && tar -xzf ruby.tar.gz && cd "ruby-${target_version}"

	# Configure and build Ruby
	./configure --prefix="$ruby_dir" --with-openssl-dir=$(command -v openssl >/dev/null && openssl version -d | cut -d' ' -f2 | tr -d '"') && make && sudo make install
	local build_status=$?

	# Create symlinks if build was successful
	if [ $build_status -eq 0 ] && [ -f "$ruby_dir/bin/ruby" ]; then
		create_managed_symlink "$ruby_dir/bin/ruby" "$BASE_DIR/bin/ruby"
		create_managed_symlink "$ruby_dir/bin/gem" "$BASE_DIR/bin/gem"
		create_managed_symlink "$ruby_dir/bin/bundle" "$BASE_DIR/bin/bundle"
		create_managed_symlink "$ruby_dir/bin/irb" "$BASE_DIR/bin/irb"

		TOOLCHAIN_STATES["ruby"]="installed"
		TOOLCHAIN_VERSIONS["ruby"]=$(ruby -e 'puts RUBY_VERSION' 2>/dev/null || echo "$target_version")
		info "Ruby $target_version successfully installed from source"
	else
		TOOLCHAIN_STATES["ruby"]="failed"
		TOOLCHAIN_VERSIONS["ruby"]="unknown"
		warn "Ruby source installation failed. Falling back to package manager."

		# Fallback to package manager
		case "$PACKAGE_MANAGER" in
		apt)
			sudo apt-get update
			sudo apt-get install -y ruby-full ruby-dev
			;;
		dnf)
			sudo dnf install -y ruby ruby-devel
			;;
		pacman)
			sudo pacman -Sy --noconfirm ruby
			;;
		brew)
			brew install ruby
			;;
		esac

		# Create symlinks to system Ruby
		if command -v ruby >/dev/null 2>&1; then
			local system_ruby_path=$(command -v ruby)
			local system_gem_path=$(command -v gem)

			create_managed_symlink "$system_ruby_path" "$BASE_DIR/bin/ruby"
			if [ -n "$system_gem_path" ]; then
				create_managed_symlink "$system_gem_path" "$BASE_DIR/bin/gem"
			fi

			TOOLCHAIN_STATES["ruby"]="installed"
			TOOLCHAIN_VERSIONS["ruby"]=$(ruby -e 'puts RUBY_VERSION' 2>/dev/null || echo "unknown")
			info "Ruby installed from package manager: $(ruby -e 'puts RUBY_VERSION' 2>/dev/null || echo "unknown")"
		else
			TOOLCHAIN_STATES["ruby"]="failed"
			TOOLCHAIN_VERSIONS["ruby"]="unknown"
			warn "Ruby installation failed completely"
		fi
	fi

	# Clean up
	rm -rf "$tmp_dir"
}
###############################################################################
# Summary Report
###############################################################################

print_summary() {
	echo
	echo "Toolchain Installation Summary:"
	echo "------------------------------"
	for toolchain in "${!TOOLCHAIN_STATES[@]}"; do
		printf "%-15s: %-10s (version: %s)\n" \
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
	install_ruby || {
		warn "Ruby installation failed, continuing..."
		true
	}
	# Print installation summary
	print_summary
}

# Execute main function
main "$@"
