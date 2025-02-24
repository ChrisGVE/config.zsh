# ZSH Configuration and Tools Management

A comprehensive system for managing ZSH configuration and development tools across different environments (macOS and Linux).

## Purpose

This repository provides:

1. A portable set of tools for macOS and Linux
2. Standard ZSH configuration that works across platforms
3. System-wide installation of dependencies and tools
4. User-specific configuration management

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
│   └── toolchains/              - Development toolchains
│       ├── conda/               - Miniconda installation
│       ├── rust/                - Rust toolchain
│       └── ...
└── lib/                          - Libraries
```

## Supported Tools

| Tool       | Description                                 |
| ---------- | ------------------------------------------- |
| bat        | A cat clone with syntax highlighting        |
| bat-extras | Extensions for bat (batdiff, batgrep, etc.) |
| delta      | A viewer for git and diff output            |
| figlet     | ASCII art text generator                    |
| fzf        | Command-line fuzzy finder                   |
| lazygit    | Terminal UI for git commands                |
| lolcat     | Rainbow text colorizer                      |
| nvim       | Neovim text editor                          |
| tmux       | Terminal multiplexer                        |
| tv         | Terminal media player                       |
| uv         | Fast Python package installer               |
| yazi       | Terminal file manager                       |
| zoxide     | Smarter cd command                          |

## Installation

### Prerequisites

- Git
- Sudo access

### System-Wide Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/YourUsername/zsh-config.git ~/.config/zsh
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
user-post-install.sh
```

This will:

- Create symlinks for ZSH configuration
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
nvim=stable, config            # Build from stable with config
fzf=head                       # Build from latest HEAD
bat=stable, config, post="bat cache --build"  # With post-command
tmux=managed                   # Install via package manager
lazygit=none                   # Skip installation
```

## Customization

- ZSH configuration: Modify `~/.config/zsh/zshrc`
- Tool configuration: Add configs to GitHub as `config.TOOL_NAME`
- Add new tools: Create scripts in `~/.config/zsh/install/tools/`

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
