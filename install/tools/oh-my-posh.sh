#!/usr/bin/env bash

###############################################################################
# Oh My Posh Installation Script
#
# Purpose:
# Installs or updates Oh My Posh (https://ohmyposh.dev/)
# A prompt theme engine for any shell
#
# Features:
# - Cross-platform installation (macOS, Linux, Raspberry Pi)
# - Configuration template setup
# - Default theme installation
###############################################################################

# Source common functions
source "$(dirname "$0")/../common.sh"

# Tool-specific configuration
TOOL_NAME="oh-my-posh"
BINARY="oh-my-posh"
VERSION_CMD="--version"

###############################################################################
# Installation Functions
###############################################################################

# Platform-specific installation method
install_oh_my_posh() {
	local installation_dir="$BASE_DIR/share/oh-my-posh"

	# Create installation directory
	sudo mkdir -p "$installation_dir"
	sudo chown root:$ADMIN_GROUP "$installation_dir"
	sudo chmod 775 "$installation_dir"

	# Determine platform-specific installation
	case "$OS_TYPE" in
	macos)
		if command -v brew >/dev/null 2>&1; then
			info "Installing Oh My Posh via Homebrew on macOS"
			if ! brew list jandedobbeleer/oh-my-posh/oh-my-posh &>/dev/null; then
				brew install jandedobbeleer/oh-my-posh/oh-my-posh
			else
				brew upgrade jandedobbeleer/oh-my-posh/oh-my-posh || true
			fi

			# Create symlink to Homebrew's oh-my-posh
			if [ -f "$HOMEBREW_PREFIX/bin/oh-my-posh" ]; then
				create_managed_symlink "$HOMEBREW_PREFIX/bin/oh-my-posh" "$BASE_DIR/bin/oh-my-posh"
				return 0
			else
				return 1
			fi
		else
			info "Homebrew not found, installing Oh My Posh directly"
			install_direct
		fi
		;;
	linux | raspberrypi)
		install_direct
		;;
	*)
		error "Unsupported platform: $OS_TYPE"
		;;
	esac
}

# Direct installation method using the official install script
install_direct() {
	local installation_dir="$BASE_DIR/share/oh-my-posh"
	local tmp_dir=$(mktemp -d)

	info "Installing Oh My Posh directly from official source..."

	# Download the latest version
	curl -s https://ohmyposh.dev/install.sh >"$tmp_dir/install.sh"
	chmod +x "$tmp_dir/install.sh"

	# Install to the installation directory
	sudo bash "$tmp_dir/install.sh" -d "$installation_dir"

	# Create symlink if installation succeeded
	if [ -f "$installation_dir/oh-my-posh" ]; then
		create_managed_symlink "$installation_dir/oh-my-posh" "$BASE_DIR/bin/oh-my-posh"

		# Clean up themes directory and copy defaults
		setup_themes "$installation_dir"

		rm -rf "$tmp_dir"
		return 0
	else
		rm -rf "$tmp_dir"
		return 1
	fi
}

# Setup themes for Oh My Posh
setup_themes() {
	local installation_dir="$1"

	# Create themes directory
	sudo mkdir -p "$installation_dir/themes"
	sudo chown root:$ADMIN_GROUP "$installation_dir/themes"
	sudo chmod 775 "$installation_dir/themes"

	# Download popular themes if they don't exist
	local themes_to_download=(
		"catppuccin_mocha.omp.json"
		"catppuccin_macchiato.omp.json"
		"catppuccin_frappe.omp.json"
		"catppuccin_latte.omp.json"
		"powerlevel10k_classic.omp.json"
		"powerlevel10k_rainbow.omp.json"
		"agnoster.omp.json"
		"atomic.omp.json"
		"paradox.omp.json"
		"quick-term.omp.json"
		"sonicboom.omp.json"
		"star.omp.json"
	)

	for theme in "${themes_to_download[@]}"; do
		if [ ! -f "$installation_dir/themes/$theme" ]; then
			sudo curl -s -o "$installation_dir/themes/$theme" \
				"https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/$theme" ||
				warn "Failed to download theme: $theme"
		fi
	done

	# Set permissions for all theme files
	sudo chown -R root:$ADMIN_GROUP "$installation_dir/themes"
	sudo chmod -R 664 "$installation_dir/themes"/*
}

###############################################################################
# Main Installation Process
###############################################################################

main() {
	info "Starting installation of $TOOL_NAME..."

	# Parse tool configuration
	parse_tool_config "$TOOL_NAME"

	# Install Oh My Posh
	if install_oh_my_posh; then
		# Verify installation
		if command -v oh-my-posh >/dev/null 2>&1; then
			local version=$(oh-my-posh --version 2>/dev/null | head -n1)
			info "Oh My Posh installed successfully - version: $version"

			# Create user config directory if it doesn't exist
			if [ ! -d "$HOME/.config/zsh/oh-my-posh" ]; then
				mkdir -p "$HOME/.config/zsh/oh-my-posh"
			fi

			# Copy a default theme to user config if needed
			if [ ! -f "$HOME/.config/zsh/oh-my-posh/config.yml" ]; then
				# Find themes directory
				local themes_dir="$BASE_DIR/share/oh-my-posh/themes"
				if [ -d "$themes_dir" ] && [ -f "$themes_dir/catppuccin_mocha.omp.json" ]; then
					cp "$themes_dir/catppuccin_mocha.omp.json" "$HOME/.config/zsh/oh-my-posh/config.yml"
					info "Default theme copied to $HOME/.config/zsh/oh-my-posh/config.yml"
				else
					# Create a basic config
					cat >"$HOME/.config/zsh/oh-my-posh/config.yml" <<'EOL'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "blocks": [
    {
      "alignment": "left",
      "segments": [
        {
          "foreground": "#5FAAE8",
          "style": "plain",
          "template": "{{ .UserName }}@{{ .HostName }} ",
          "type": "session"
        },
        {
          "foreground": "#BF616A",
          "properties": {
            "style": "folder"
          },
          "style": "plain",
          "template": "<#A3BE8C>in</> {{ .Path }} ",
          "type": "path"
        },
        {
          "foreground": "#EBCB8B",
          "properties": {
            "branch_icon": ""
          },
          "style": "plain",
          "template": "<#88C0D0>on</> {{ .HEAD }} ",
          "type": "git"
        }
      ],
      "type": "prompt"
    },
    {
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "foreground": "#5FAAE8",
          "style": "plain",
          "template": "$ ",
          "type": "text"
        }
      ],
      "type": "prompt"
    }
  ],
  "version": 2
}
EOL
					info "Basic theme created at $HOME/.config/zsh/oh-my-posh/config.yml"
				fi
			fi
		else
			warn "Oh My Posh binary not found in PATH after installation"
		fi
	else
		error "Failed to install Oh My Posh"
	fi

	info "$TOOL_NAME installation completed successfully"
}

# Run the main installation
main
