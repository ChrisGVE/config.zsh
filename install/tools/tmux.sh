#!/usr/bin/env bash

###############################################################################
# Tmux Installation Script
#
# Purpose:
# Installs or updates tmux (https://github.com/tmux/tmux)
# A terminal multiplexer
#
# Dependencies:
# - libevent
# - ncurses
# - build tools
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="tmux"
REPO_URL="https://github.com/tmux/tmux"
BINARY="tmux"
VERSION_CMD="-V"

###############################################################################
# Installation Functions
###############################################################################

install_deps() {
    info "Installing $TOOL_NAME build dependencies..."
    package_install "libevent-dev"
    package_install "libncurses-dev"
    package_install "automake"
    package_install "pkg-config"
    package_install "build-essential"
    package_install "bison"
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
    sudo -u root git reset --hard || warn "Failed to reset git repository"
    sudo -u root git clean -fd || warn "Failed to clean git repository"
    
    # Configure git trust
    sudo git config --global --add safe.directory "$build_dir"

    # Checkout appropriate version
    # Note: tmux versions don't have 'v' prefix
    if [ "$version_type" = "stable" ]; then
        # Get all tags and match the most recent digit-only tag
        local latest_version=$(git tag -l | grep -E '^[0-9]+(\.[0-9]+)*$' | sort -V | tail -n1)

        if [ -z "$latest_version" ]; then
            error "No valid version tags found"
        fi

        info "Building version: $latest_version"
        sudo -u root git checkout "$latest_version" || error "Failed to checkout version $latest_version"
    else
        info "Building from latest HEAD"
        sudo -u root git checkout master || sudo -u root git checkout main || error "Failed to checkout master/main branch"
    fi

    info "Building $TOOL_NAME..."

    # Generate autotools files
    sh autogen.sh || error "Failed to generate build system"

    # Configure build flags
    configure_build_flags

    # Configure and build
    ./configure --prefix="$BASE_DIR" || error "Failed to configure"
    make $MAKE_FLAGS || error "Failed to build"

    info "Installing $TOOL_NAME..."
    sudo make install || error "Failed to install"
}

###############################################################################
# Main Installation Process
###############################################################################

# Install dependencies first
install_deps

# Setup repository in cache
REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

# Run installation/update
install_or_update_tool "$TOOL_NAME" "$BINARY" "$VERSION_CMD" "$REPO_DIR" build_tool
