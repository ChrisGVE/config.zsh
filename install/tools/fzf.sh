#!/usr/bin/env bash

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="fzf"
REPO_URL="https://github.com/junegunn/fzf"
BINARY="fzf"
VERSION_CMD="--version"

# Install dependencies
install_deps() {
    info "Installing $TOOL_NAME build dependencies..."
    
    case "$TOOL_NAME" in
    # No specific dependencies
}

# Build the tool from source
build_tool() {
    local build_dir="$1"
    local version_type="$2"
    
    if [ ! -d "$build_dir" ]; then
        error "Build directory does not exist: $build_dir"
        return 1
    fi
    
    # Enter build directory
    cd "$build_dir" || { error "Failed to enter build directory: $build_dir"; return 1; }
    
    # Reset and clean the repository
    sudo -u root git reset --hard || { warn "Failed to reset git repository"; }
    sudo -u root git clean -fd || { warn "Failed to clean git repository"; }
    
    # Configure git trust
    sudo git config --global --add safe.directory "$build_dir"
    
    # Checkout appropriate version
    if [ "$version_type" = "stable" ]; then
        # Try to get latest tag
        local latest_version=$(git tag -l | grep -E '^v?[0-9]+(\.[0-9]+)*$' | sort -V | tail -n1)
        
        if [ -n "$latest_version" ]; then
            info "Building version: $latest_version"
            sudo -u root git checkout "$latest_version" || { error "Failed to checkout version $latest_version"; return 1; }
        else
            info "No version tags found, using master branch"
            sudo -u root git checkout master || sudo -u root git checkout main || { error "Failed to checkout master branch"; return 1; }
        fi
    else
        info "Building from latest HEAD"
        sudo -u root git checkout master || sudo -u root git checkout main || { error "Failed to checkout master/main branch"; return 1; }
    fi
    
    info "Building $TOOL_NAME..."
    
    make clean || true
    make || error "Failed to build"
    
    # Install the binary
    sudo install -m755 bin/fzf "$BASE_DIR/bin/" || error "Failed to install binary"
    
    # Install shell completion and key bindings
    sudo mkdir -p "$BASE_DIR/share/fzf"
    sudo cp shell/*.zsh "$BASE_DIR/share/fzf/"
    sudo cp shell/*.bash "$BASE_DIR/share/fzf/"
    sudo cp shell/*.fish "$BASE_DIR/share/fzf/"
}

# Install dependencies first
install_deps

# Setup repository in cache
REPO_DIR=$(setup_tool_repo "$TOOL_NAME" "$REPO_URL")

# Run installation/update
install_or_update_tool "$TOOL_NAME" "$BINARY" "$VERSION_CMD" "$REPO_DIR" build_tool
