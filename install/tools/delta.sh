#!/usr/bin/env bash

###############################################################################
# Delta Installation Script (Simplified)
#
# Purpose:
# Installs or updates delta (https://github.com/dandavison/delta)
# A syntax-highlighting pager for git, diff, and grep output
###############################################################################

set -o pipefail

# Source common functions but don't use their parsing
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="delta"
BINARY="delta"

# Skip normal parsing and use direct installation
info "Installing delta on Raspberry Pi..."

# Attempt to install via package manager first (most reliable)
info "Attempting to install via package manager..."
sudo apt-get update
sudo apt-get install -y git-delta

# Check if installation succeeded
if command -v git-delta >/dev/null 2>&1; then
	info "git-delta command available: $(which git-delta)"

	# Create symlink to delta if needed
	if ! command -v delta >/dev/null 2>&1; then
		info "Creating symlink from git-delta to delta"
		sudo ln -sf "$(which git-delta)" "$BASE_DIR/bin/delta"
	fi

	# Configure git to use delta
	info "Configuring git to use delta..."
	git config --global core.pager delta
	git config --global interactive.diffFilter "delta --color-only"
	git config --global delta.navigate true
	git config --global merge.conflictStyle zdiff3

	info "Delta installation and configuration completed successfully"
	exit 0
fi

# If package manager failed, try direct download
info "Package manager installation failed, trying direct download..."

# Create temp directory
TMP_DIR=$(mktemp -d)

# Find the latest release
info "Finding latest delta release..."
VERSION=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest |
	grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)

if [ -z "$VERSION" ]; then
	warn "Could not determine latest version, using fallback version"
	VERSION="0.16.5"
fi

info "Latest version: $VERSION"
VERSION=${VERSION#v} # Remove 'v' prefix if present

# Download the appropriate package for Raspberry Pi (ARM64)
DEB_FILE="git-delta_${VERSION}_arm64.deb"
DOWNLOAD_URL="https://github.com/dandavison/delta/releases/download/${VERSION}/${DEB_FILE}"

info "Downloading from: $DOWNLOAD_URL"
if curl -L -o "$TMP_DIR/$DEB_FILE" "$DOWNLOAD_URL"; then
	info "Installing deb package..."
	sudo dpkg -i "$TMP_DIR/$DEB_FILE" || {
		warn "Failed to install deb package"
		rm -rf "$TMP_DIR"
		exit 1
	}

	# Create symlink if needed
	if command -v git-delta >/dev/null 2>&1 && ! command -v delta >/dev/null 2>&1; then
		info "Creating symlink from git-delta to delta"
		sudo ln -sf "$(which git-delta)" "$BASE_DIR/bin/delta"
	fi

	# Configure git
	info "Configuring git to use delta..."
	git config --global core.pager delta
	git config --global interactive.diffFilter "delta --color-only"
	git config --global delta.navigate true
	git config --global merge.conflictStyle zdiff3

	rm -rf "$TMP_DIR"
	info "Delta installation and configuration completed successfully"
else
	warn "Failed to download deb package"
	rm -rf "$TMP_DIR"
	exit 1
fi
