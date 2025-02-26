# TODO List

## Platform Support

### macOS Support

- [x] Test on macOS with Homebrew
- [x] Add macOS-specific default configuration
- [x] Handle macOS-specific path issues
- [x] Test with both Intel and Apple Silicon

### Linux Distribution Support

- [x] Raspberry Pi / Debian / Ubuntu - implemented and tested
- [x] Add Raspberry Pi resource optimization
- [ ] Improve Fedora / RHEL / CentOS support
- [ ] Enhance Arch / Manjaro support
- [ ] Add Alpine Linux support
- [ ] Add NixOS support

## Tools Enhancement

- [x] Fix repository handling for all tools
- [x] Improve version detection and switching
- [x] Add resource limits for Raspberry Pi builds
- [x] Use pre-built binaries when available
- [ ] Add support for more programming language toolchains
- [ ] Add support for containerization tools (Docker, Podman)
- [ ] Add rollback capabilities for failed installations

## Performance Improvements

- [x] Add resource limits for Raspberry Pi builds
- [ ] Add parallel installation option (low priority for Pi)
- [x] Optimize build flags for different platforms
- [x] Implement better caching for downloaded sources
- [ ] Implement incremental updates for large repositories

## ZSH Configuration

- [x] Fix zoxide integration across platforms
- [x] Add platform-specific plugin detection
- [ ] Improve plugin load time
- [ ] Add better error handling for missing plugins
- [ ] Create a minimal configuration for resource-constrained systems

## Documentation

- [x] Update README with cross-platform information
- [x] Add platform-specific notes
- [ ] Create detailed documentation for each tool
- [ ] Add troubleshooting guides
- [ ] Create installation videos/tutorials

## User Experience

- [ ] Add interactive mode for installation
- [ ] Create TUI for managing tools
- [ ] Add progress indicators for long-running tasks
- [x] Implement better logging system
- [ ] Add a graphical configuration tool

## Testing

- [ ] Create automated tests for installation
- [ ] Test in CI environments
- [ ] Create test VMs for different platforms
- [ ] Add integration tests for zsh configuration

## Security

- [ ] Verify all source code before building
- [ ] Implement checksum verification
- [ ] Add signature verification for downloads
- [ ] Add sandboxing for builds

## Miscellaneous

- [x] Refactor common functionality
- [x] Improve error messages
- [ ] Add uninstall functionality
- [ ] Add update notification system
- [ ] Create a migration tool for existing configurations
