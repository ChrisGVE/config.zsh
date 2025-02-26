#!/usr/bin/env bash

###############################################################################
# FZF Installation Script
#
# Purpose:
# Installs or updates fzf (https://github.com/junegunn/fzf)
# A command-line fuzzy finder
#
# Dependencies:
# - Go toolchain (automatically managed)
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="fzf"
REPO_URL="https://github.com/junegunn/fzf"
BINARY="fzf"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
	info "Installing $TOOL_NAME build dependencies..."
	# Check if Go is in PATH
	if ! command -v go >/dev/null 2>&1; then
		info "Go not found in PATH, checking for Go installation..."

		# Check for Go in our toolchain location
		local go_bin="$BASE_DIR/share/dev/toolchains/go/bin/go"

		if [ -f "$go_bin" ]; then
			info "Found Go at $go_bin, adding to PATH"
			export PATH="$BASE_DIR/share/dev/toolchains/go/bin:$PATH"
		else
			info "Go not found in expected location, attempting installation..."

			# Check OS type
			case "$OS_TYPE" in
			macos)
				if command -v brew >/dev/null 2>&1; then
					brew install go
				else
					warn "Homebrew not found, cannot install Go automatically"
				fi
				;;
			linux | raspberrypi)
				case "$PACKAGE_MANAGER" in
				apt)
					sudo apt-get update
					sudo apt-get install -y golang
					;;
				dnf)
					sudo dnf install -y golang
					;;
				pacman)
					sudo pacman -Sy --noconfirm go
					;;
				*)
					warn "Unknown package manager, cannot install Go automatically"
					;;
				esac
				;;
			esac
		fi
	fi

	# Final verification
	if ! command -v go >/dev/null 2>&1; then
		error "Go is required but not available in PATH after setup attempts"
	else
		info "Go is available: $(go version)"
	fi
}

build_tool() {
	local build_dir="$1"
	local version_type="$2"

	# Ensure build directory exists
	if [ ! -d "$build_dir" ]; then
		error "Build directory does not exist: $build_dir"
		return 1
	fi

	# Enter build directory
	cd "$build_dir" || error "Failed to enter build directory: $build_dir"

	# Reset and clean the repository to handle any local changes
	sudo git reset --hard || warn "Failed to reset git repository"
	sudo git clean -fd || warn "Failed to clean git repository"

	# Configure git trust for this repository
	(cd "$build_dir" && sudo git config --local core.trustctime false)
	sudo chmod -R g+w "$build_dir"

	# Checkout appropriate version
	if [ "$version_type" = "stable" ]; then
		# Try to get latest tag
		local latest_version=$(git tag -l | grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -n1)

		if [ -n "$latest_version" ]; then
			info "Building version: $latest_version"
			sudo git checkout "$latest_version" || error "Failed to checkout version $latest_version"
		else
			info "No version tags found, using master branch"
			sudo git checkout master || error "Failed to checkout master branch"
		fi
	else
		info "Building from latest HEAD"
		sudo git checkout master || error "Failed to checkout master branch"
	fi

	info "Building $TOOL_NAME..."

	# For Raspberry Pi, use prebuilt binary if available
	if [ "$OS_TYPE" = "raspberrypi" ] && [ "$(uname -m)" = "aarch64" ]; then
		info "Attempting to use pre-built binary for Raspberry Pi..."

		# Get version without 'v' prefix if it exists
		local version=${latest_version#v}

		# Try to download pre-built binary
		./install --bin

		if [ -f "bin/fzf" ]; then
			info "Using pre-built binary from installer script"
			sudo install -m755 bin/fzf "$BASE_DIR/bin/" || error "Failed to install binary"

			# Install shell scripts
			sudo mkdir -p "$BASE_DIR/share/fzf"
			sudo cp shell/completion.zsh "$BASE_DIR/share/fzf/"
			sudo cp shell/key-bindings.zsh "$BASE_DIR/share/fzf/"
			return 0
		else
			info "Pre-built binary not available, building from source"
		fi
	fi

	# Configure for go build
	configure_build_flags
	export GOPATH="$build_dir/go"
	mkdir -p "$GOPATH"

	# Set compile flags for different architectures
	local arch="$(uname -m)"
	local compile_flags=""

	case "$arch" in
	aarch64 | arm64)
		compile_flags="GOARCH=arm64"
		;;
	armv7l)
		compile_flags="GOARCH=arm"
		;;
	x86_64)
		compile_flags="GOARCH=amd64"
		;;
	esac

	# Build with go
	sudo -E env PATH="$PATH" $compile_flags make

	info "Installing $TOOL_NAME..."

	# Check if binary exists
	if [ -f "bin/fzf" ]; then
		sudo install -m755 bin/fzf "$BASE_DIR/bin/" || error "Failed to install binary"
	else
		error "Binary not found at bin/fzf after build"
	fi

	# Install shell completion and key bindings to system location for all users
	sudo mkdir -p "$BASE_DIR/share/fzf"
	if [ -f "shell/completion.zsh" ]; then
		sudo cp shell/completion.zsh "$BASE_DIR/share/fzf/"
		sudo cp shell/key-bindings.zsh "$BASE_DIR/share/fzf/"
	fi
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting installation of $TOOL_NAME..."

	# Install dependencies
	install_deps

	# Setup repository in cache
	REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

	# Parse tool configuration
	parse_tool_config "$TOOL_NAME"

	# Try using the provided installer first (which downloads prebuilt binaries)
	if [ "$OS_TYPE" = "macos" ] || [ "$OS_TYPE" = "raspberrypi" ] || [ "$OS_TYPE" = "linux" ]; then
		info "Attempting to use fzf's own installer script first..."

		cd "$REPO_DIR" || error "Failed to enter repository directory"

		# The fzf installer can handle downloading binaries for us
		./install --bin

		if [ -f "bin/fzf" ]; then
			info "fzf binary successfully built by installer script"
			sudo install -m755 bin/fzf "$BASE_DIR/bin/" || warn "Failed to install fzf binary, will try building from source"

			# Install shell scripts
			sudo mkdir -p "$BASE_DIR/share/fzf"
			sudo cp shell/completion.zsh "$BASE_DIR/share/fzf/"
			sudo cp shell/key-bindings.zsh "$BASE_DIR/share/fzf/"

			info "fzf successfully installed"
			return 0
		else
			info "fzf installer didn't produce a binary, falling back to source build"
		fi
	fi

	# Build and install
	build_tool "$REPO_DIR" "$TOOL_VERSION_TYPE"

	info "$TOOL_NAME installation completed successfully"
}

# Run the main installation
main
