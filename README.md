# ZSH Configuration and Tools Management

A comprehensive system for managing ZSH configuration and development tools across different environments (macOS, Linux, and Raspberry Pi).

## Purpose

This repository provides:

1. A portable set of tools for macOS, Linux, and Raspberry Pi
2. Standard ZSH configuration that works across platforms
3. System-wide installation of dependencies and tools
4. User-specific configuration management
5. Automatic detection and adaptation to different platforms

## Directory Structure

```
~/.config/zsh/                    - Main configuration directory
├── install/                      - Installation support scripts
│   ├── common.sh                 - Common functions
│   ├── toolchains.sh             - Toolchain management
│   ├── tools.conf                - Tool configuration
│   └── tools/                    - Individual tool installers
│       ├── bat.sh
│       ├── nvim.sh
│       └── ...
├── plugins/                      - ZSH plugins
│   ├── zsh-autosuggestions/
│   ├── fast-syntax-highlighting/
│   └── zsh-vi-mode/
├── oh-my-posh/                   - Oh My Posh theme configuration
├── themes/                       - Catppuccin and other themes
├── zshenv                        - ZSH environment variables
├── zshrc                         - ZSH configuration
├── dependencies.sh               - Main system-wide installer
└── user-post-install.sh          - User-specific setup
```

## System-Wide Installation Paths

```
/opt/local/ or /usr/local/        - Base installation directory
├── bin/                          - Executables and symlinks
├── etc/dev/                      - Configuration files
├── share/dev/                    - Shared data
│   ├── cache/                   - Repository cache
│   └── toolchains/              - Development toolchains
│       ├── conda/               - Miniconda installation
│       ├── rust/                - Rust toolchain
│       ├── go/                  - Go installation
│       ├── ruby/                - Ruby installation
│       └── ...
└── lib/                          - Libraries
```

## Supported Platforms

| Platform      | Status             | Notes                      |
| ------------- | ------------------ | -------------------------- |
| macOS         | ✅ Fully Supported | Intel and Apple Silicon    |
| Debian/Ubuntu | ✅ Fully Supported | Includes Raspberry Pi OS   |
| Raspberry Pi  | ✅ Fully Supported | Optimized resource usage   |
| Fedora/RHEL   | ⚠️ Basic Support   | Package management working |
| Arch Linux    | ⚠️ Basic Support   | Package management working |

## Supported Tools

| Tool       | Description                                 | Platforms         |
| ---------- | ------------------------------------------- | ----------------- |
| bat        | A cat clone with syntax highlighting        | All               |
| bat-extras | Extensions for bat (batdiff, batgrep, etc.) | All               |
| delta      | A viewer for git and diff output            | All               |
| figlet     | ASCII art text generator                    | All               |
| fzf        | Command-line fuzzy finder                   | All               |
| lazygit    | Terminal UI for git commands                | All               |
| lolcat     | Rainbow text colorizer                      | All               |
| nvim       | Neovim text editor                          | All               |
| oh-my-posh | Shell prompt theme engine                   | All               |
| tmux       | Terminal multiplexer                        | All               |
| tv         | Terminal media player                       | All               |
| uv         | Fast Python package installer               | All (Limited RPi) |
| yazi       | Terminal file manager                       | All               |
| zoxide     | Smarter cd command                          | All               |

## Installation

### Prerequisites

- Git
- Sudo access

### System-Wide Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/ChrisGVE/zsh-config.git ~/.config/zsh
   ```

2. Run the install script:

   ```bash
   cd ~/.config/zsh
   ./install.sh
   ```

3. Install all tools and dependencies:
   ```bash
   dependencies
   ```

### User-Specific Setup

After system-wide installation, run the user-specific setup:

```bash
~/.config/zsh/user-post-install.sh
```

This will:

- Create symlinks for ZSH configuration
- Install and configure ZSH plugins (oh-my-zsh, oh-my-posh, etc.)
- Clone any user-specific tool configurations
- Run post-installation commands

## Configuration

### Tools Configuration

Tools are configured in `tools.conf` with the format:

```
TOOL_NAME=version_type[, config][, post="command"]
```

Where:

- `version_type`: stable, head, managed, none
- `config`: Optional flag to install configuration
- `post`: Optional post-installation command

For example:

```
nvim=head, config            # Build from development branch with config
fzf=stable                   # Build from stable release
bat=stable, config, post="bat cache --build"  # With post-command
tmux=managed                 # Install via package manager
lazygit=none                 # Skip installation
```

## Customization

- ZSH configuration: Modify `~/.config/zsh/zshrc`
- Tool configuration: Add configs to GitHub as `config.TOOL_NAME`
- Add new tools: Create scripts in `~/.config/zsh/install/tools/`

## Cross-Platform Features

- Automatic platform detection (macOS, Linux, Raspberry Pi)
- Adaptive package management
- Optimized resource usage for Raspberry Pi
- Prebuilt binaries used when available
- Consistent environment across platforms

## Development

To add support for a new tool:

1. Create a script in `~/.config/zsh/install/tools/`
2. Add the tool to `tools.conf`
3. Optionally create a config repository named `config.TOOL_NAME`

## Troubleshooting

- Check logs for error messages
- Ensure sudo access is available
- Verify tool dependencies are installed
- For user-specific issues, check `~/.config` permissions
- Use `rawcd` command to bypass zoxide if you experience cd issues
