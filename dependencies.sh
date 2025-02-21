#!/usr/bin/env bash

set -euo pipefail

# Detect OS
case "$(uname -s)" in
Darwin*)
	export OS_TYPE="macos"
	;;
Linux*)
	export OS_TYPE="linux"
	if [[ -f /sys/firmware/devicetree/base/model ]]; then
		if grep -q "Raspberry Pi" /sys/firmware/devicetree/base/model; then
			export OS_TYPE="raspberrypi"
		fi
	fi
	;;
*)
	export OS_TYPE="unknown"
	;;
esac

# Print status messages
info() {
	echo "[INFO] $1"
}

warning() {
	echo "[WARNING] $1"
}

error() {
	echo "[ERROR] $1"
	exit 1
}

# Check if a command exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Setup symlinks for zsh configuration
setup_symlinks() {
	info "Setting up symlinks..."

	# Backup existing files if they're not symlinks
	for file in "$HOME/.zshenv" "$HOME/.zshrc"; do
		if [[ -f "$file" && ! -L "$file" ]]; then
			mv "$file" "$file.backup.$(date +%Y%m%d%H%M%S)"
			info "Backed up existing $file"
		fi
	done

	# Create symlinks
	ln -sf "$XDG_CONFIG_HOME/zsh/zshenv" "$HOME/.zshenv"
	ln -sf "$XDG_CONFIG_HOME/zsh/zshrc" "$HOME/.zshrc"
}

# Install package based on OS
install_package() {
	local package_name="$1"
	local mac_package="${2:-$1}"
	local debian_package="${3:-$1}"

	case "$OS_TYPE" in
	macos)
		if ! command_exists brew; then
			error "Homebrew is not installed. Please install it first."
		fi
		if ! brew list "$mac_package" >/dev/null 2>&1; then
			info "Installing $mac_package via Homebrew..."
			brew install "$mac_package"
		else
			info "$mac_package already installed"
		fi
		;;
	raspberrypi | linux)
		if ! command_exists apt-get; then
			error "This script currently only supports Debian-based Linux distributions"
		fi
		if ! dpkg -l "$debian_package" >/dev/null 2>&1; then
			info "Installing $debian_package via apt..."
			sudo apt-get update
			sudo apt-get install -y "$debian_package"
		else
			info "$debian_package already installed"
		fi
		;;
	*)
		error "Unsupported operating system"
		;;
	esac
}

# Install ZSH plugins
install_zsh_plugins() {
	local plugin_dir="${XDG_DATA_HOME}/zsh/plugins"

	case "$OS_TYPE" in
	raspberrypi | linux)
		# zsh-autosuggestions
		if [ ! -d "$plugin_dir/zsh-autosuggestions" ]; then
			info "Installing zsh-autosuggestions..."
			git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions"
		fi

		# zsh-fast-syntax-highlighting
		if [ ! -d "$plugin_dir/fast-syntax-highlighting" ]; then
			info "Installing fast-syntax-highlighting..."
			git clone https://github.com/zdharma-continuum/fast-syntax-highlighting "$plugin_dir/fast-syntax-highlighting"
		fi

		# zsh-vi-mode
		if [ ! -d "$plugin_dir/zsh-vi-mode" ]; then
			info "Installing zsh-vi-mode..."
			git clone https://github.com/jeffreytse/zsh-vi-mode "$plugin_dir/zsh-vi-mode"
		fi
		;;
	macos)
		info "On macOS, plugins will be installed via Homebrew"
		brew install zsh-autosuggestions zsh-fast-syntax-highlighting zsh-vi-mode
		;;
	esac
}

# Install oh-my-zsh if not already installed
install_omz() {
	if [ ! -d "${XDG_CONFIG_HOME}/zsh/ohmyzsh" ]; then
		info "Installing oh-my-zsh..."
		export ZSH="${XDG_CONFIG_HOME}/zsh/ohmyzsh"
		sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
	fi
}

# Install oh-my-posh
install_oh_my_posh() {
	if ! command_exists oh-my-posh; then
		case "$OS_TYPE" in
		macos)
			brew install jandedobbeleer/oh-my-posh/oh-my-posh
			;;
		raspberrypi | linux)
			info "Installing oh-my-posh..."
			curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "${XDG_BIN_HOME}"
			;;
		esac
	fi
}

# Setup bat/batcat symlink on Linux systems
setup_bat() {
	if [[ "$OS_TYPE" == "raspberrypi" || "$OS_TYPE" == "linux" ]]; then
		if command_exists batcat && ! command_exists bat; then
			info "Creating bat -> batcat symlink..."
			mkdir -p "${XDG_BIN_HOME}"
			ln -sf "$(which batcat)" "${XDG_BIN_HOME}/bat"
		fi
	fi
}

# Install Neovim from source
install_neovim() {
	case "$OS_TYPE" in
	macos)
		brew install neovim
		;;
	raspberrypi | linux)
		info "Installing Neovim build dependencies..."
		sudo apt-get update
		sudo apt-get install -y ninja-build gettext cmake unzip curl

		local build_dir="/tmp/neovim-build"
		rm -rf "$build_dir"
		mkdir -p "$build_dir"
		cd "$build_dir"

		info "Cloning Neovim repository..."
		git clone https://github.com/neovim/neovim
		cd neovim

		# Get latest stable version
		latest_stable=$(git tag -l "v*" | grep -v "[ab]" | sort -V | tail -n 1)
		info "Checking out latest stable version: $latest_stable"
		git checkout $latest_stable

		info "Building Neovim..."
		make CMAKE_BUILD_TYPE=RelWithDebInfo

		info "Installing Neovim..."
		sudo make install

		info "Cleaning up build directory..."
		cd
		rm -rf "$build_dir"
		;;
	esac
}

# Main installation
main() {
	# Source zshenv to get XDG paths
	source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zshenv"

	# Create necessary directories
	mkdir -p "${XDG_CONFIG_HOME}/zsh/oh-my-posh"
	mkdir -p "${XDG_DATA_HOME}/zsh/plugins"
	mkdir -p "${XDG_BIN_HOME}"
	mkdir -p "${XDG_RUNTIME_DIR}"
	mkdir -p "${XDG_CACHE_HOME}/zsh"

	# Setup symlinks first
	setup_symlinks

	# Install Neovim first as it's set as EDITOR in zshenv
	install_neovim

	# Install core utilities
	install_package "zsh"
	install_package "fzf"
	install_package "tmux"
	install_package "bat" "bat" "bat"
	install_package "zoxide"

	# Install ZSH-related components
	install_omz
	install_zsh_plugins
	install_oh_my_posh

	# Setup bat/batcat symlink
	setup_bat

	info "Installation complete! Please restart your shell."
}

main "$@"
case "$(uname -s)" in
Darwin*)
	export OS_TYPE="macos"
	;;
Linux*)
	export OS_TYPE="linux"
	if [[ -f /sys/firmware/devicetree/base/model ]]; then
		if grep -q "Raspberry Pi" /sys/firmware/devicetree/base/model; then
			export OS_TYPE="raspberrypi"
		fi
	fi
	;;
*)
	export OS_TYPE="unknown"
	;;
esac

# Print status messages
info() {
	echo "[INFO] $1"
}

warning() {
	echo "[WARNING] $1"
}

error() {
	echo "[ERROR] $1"
	exit 1
}

# Check if a command exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Install package based on OS
install_package() {
	local package_name="$1"
	local mac_package="${2:-$1}"
	local debian_package="${3:-$1}"

	case "$OS_TYPE" in
	macos)
		if ! command_exists brew; then
			error "Homebrew is not installed. Please install it first."
		fi
		if ! brew list "$mac_package" >/dev/null 2>&1; then
			info "Installing $mac_package via Homebrew..."
			brew install "$mac_package"
		else
			info "$mac_package already installed"
		fi
		;;
	raspberrypi | linux)
		if ! command_exists apt-get; then
			error "This script currently only supports Debian-based Linux distributions"
		fi
		if ! dpkg -l "$debian_package" >/dev/null 2>&1; then
			info "Installing $debian_package via apt..."
			sudo apt-get update
			sudo apt-get install -y "$debian_package"
		else
			info "$debian_package already installed"
		fi
		;;
	*)
		error "Unsupported operating system"
		;;
	esac
}

# Install ZSH plugins
install_zsh_plugins() {
	local plugin_dir="${XDG_DATA_HOME}/zsh/plugins"

	case "$OS_TYPE" in
	raspberrypi | linux)
		# zsh-autosuggestions
		if [ ! -d "$plugin_dir/zsh-autosuggestions" ]; then
			info "Installing zsh-autosuggestions..."
			git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions"
		fi

		# zsh-fast-syntax-highlighting
		if [ ! -d "$plugin_dir/fast-syntax-highlighting" ]; then
			info "Installing fast-syntax-highlighting..."
			git clone https://github.com/zdharma-continuum/fast-syntax-highlighting "$plugin_dir/fast-syntax-highlighting"
		fi

		# zsh-vi-mode
		if [ ! -d "$plugin_dir/zsh-vi-mode" ]; then
			info "Installing zsh-vi-mode..."
			git clone https://github.com/jeffreytse/zsh-vi-mode "$plugin_dir/zsh-vi-mode"
		fi
		;;
	macos)
		info "On macOS, plugins will be installed via Homebrew"
		brew install zsh-autosuggestions zsh-fast-syntax-highlighting zsh-vi-mode
		;;
	esac
}

# Install required packages
info "Installing required packages..."

# Core utilities
install_package "zsh"
install_package "git"
install_package "bat" "bat" "bat"
install_package "fzf"
install_package "tmux"

# Install zoxide (directory jumper)
install_package "zoxide"

# Install oh-my-posh if not installed
if ! command_exists oh-my-posh; then
	case "$OS_TYPE" in
	macos)
		brew install jandedobbeleer/oh-my-posh/oh-my-posh
		;;
	raspberrypi | linux)
		info "Installing oh-my-posh..."
		curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "${XDG_BIN_HOME}"
		;;
	esac
fi

# Set up oh-my-posh config if it doesn't exist
if [ ! -f "${XDG_CONFIG_HOME}/zsh/oh-my-posh/config.yml" ]; then
	info "Setting up oh-my-posh config..."
	mkdir -p "${XDG_CONFIG_HOME}/zsh/oh-my-posh"
	# You might want to copy your specific oh-my-posh config here
	oh-my-posh config export --config "${XDG_CONFIG_HOME}/zsh/oh-my-posh/config.yml"
fi

# Install ZSH plugins
install_zsh_plugins

# Install oh-my-zsh if not already installed
if [ ! -d "${XDG_CONFIG_HOME}/zsh/ohmyzsh" ]; then
	info "Installing oh-my-zsh..."
	export ZSH="${XDG_CONFIG_HOME}/zsh/ohmyzsh"
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
	# Move .zshrc if it was created
	if [ -f "$HOME/.zshrc" ]; then
		mv "$HOME/.zshrc" "${XDG_CONFIG_HOME}/zsh/zshrc"
	fi
fi

# Setup bat/batcat symlink on Linux systems
if [[ "$OS_TYPE" == "raspberrypi" || "$OS_TYPE" == "linux" ]]; then
	if command_exists batcat && ! command_exists bat; then
		info "Creating bat -> batcat symlink..."
		mkdir -p ~/.local/bin
		ln -sf "$(which batcat)" ~/.local/bin/bat
	fi
fi

info "Installation complete! Please restart your shell."
