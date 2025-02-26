#!/usr/bin/env bash

###############################################################################
# Delta Installation Script (Direct Download with Proper Symlink)
#
# Purpose:
# Installs or updates delta (https://github.com/dandavison/delta)
# A syntax-highlighting pager for git, diff, and grep output
###############################################################################

set -o pipefail

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="delta"
BINARY="delta"

# Skip normal parsing and use direct installation
info "Installing delta on Raspberry Pi..."

# Create temp directory
TMP_DIR=$(mktemp -d)

# Find the latest release
info "Finding latest delta release..."
RELEASE_INFO=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest)
VERSION=$(echo "$RELEASE_INFO" | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$VERSION" ]; then
	warn "Could not determine latest version, using fallback version"
	VERSION="0.16.5"
fi

info "Latest version: $VERSION"
VERSION=${VERSION#v} # Remove 'v' prefix if present

# Determine the correct package based on architecture
ARCH=$(uname -m)
info "Detected architecture: $ARCH"

if [ "$ARCH" = "aarch64" ]; then
	DEB_FILE="git-delta_${VERSION}_arm64.deb"
elif [ "$ARCH" = "armv7l" ]; then
	DEB_FILE="git-delta_${VERSION}_armhf.deb"
else
	error "Unsupported architecture: $ARCH"
	exit 1
fi

DOWNLOAD_URL="https://github.com/dandavison/delta/releases/download/${VERSION}/${DEB_FILE}"

info "Downloading from: $DOWNLOAD_URL"
if curl -L -o "$TMP_DIR/$DEB_FILE" "$DOWNLOAD_URL"; then
	info "Installing deb package..."
	sudo dpkg -i "$TMP_DIR/$DEB_FILE" || {
		warn "Failed to install deb package, checking for dependencies..."
		sudo apt-get update
		sudo apt-get install -f -y # Fix dependencies
		sudo dpkg -i "$TMP_DIR/$DEB_FILE" || {
			error "Failed to install deb package after fixing dependencies"
			rm -rf "$TMP_DIR"
			exit 1
		}
	}

	# Find the installed binary
	INSTALLED_BINARY=""
	if command -v git-delta >/dev/null 2>&1; then
		INSTALLED_BINARY=$(which git-delta)
		info "Found installed binary at: $INSTALLED_BINARY"
	elif command -v delta >/dev/null 2>&1; then
		INSTALLED_BINARY=$(which delta)
		info "Found installed binary at: $INSTALLED_BINARY"
	else
		error "Could not find installed delta binary"
		rm -rf "$TMP_DIR"
		exit 1
	fi

	# Create symlink in our managed directory
	info "Creating symlink to $BASE_DIR/bin/delta"
	sudo ln -sf "$INSTALLED_BINARY" "$BASE_DIR/bin/delta"

	# Verify the symlink
	if [ -L "$BASE_DIR/bin/delta" ]; then
		info "Symlink successfully created"
	else
		warn "Failed to create symlink"
	fi

	# Configure git
	info "Configuring git to use delta..."
	git config --global core.pager delta
	git config --global interactive.diffFilter "delta --color-only"
	git config --global delta.navigate true
	git config --global merge.conflictStyle zdiff3

	rm -rf "$TMP_DIR"
	info "Delta installation and configuration completed successfully"
	exit 0
else
	error "Failed to download deb package from $DOWNLOAD_URL"
	rm -rf "$TMP_DIR"
	exit 1
fi
