# TODO List

## Platform Support

### macOS Support

- [ ] Test fresh macOS installation with Homebrew
- [ ] Add macOS-specific default configuration
- [ ] Handle macOS-specific path issues
- [ ] Test with both Intel and Apple Silicon

### Linux Distribution Support

- [x] Raspberry Pi / Debian / Ubuntu - implemented and tested
- [ ] Fedora / RHEL / CentOS - implementation needed
- [ ] Arch / Manjaro - implementation needed
- [ ] Alpine Linux - potential lightweight option
- [ ] NixOS - potential for reproducible builds

## Tools Enhancement

- [ ] Add support for more programming language toolchains
- [ ] Add support for containerization tools (Docker, Podman)
- [ ] Improve version detection robustness
- [ ] Add rollback capabilities for failed installations

## Performance Improvements

- [ ] Add parallel installation option
- [ ] Optimize build flags for different platforms
- [ ] Implement better caching for downloaded sources

## Documentation

- [ ] Create detailed documentation for each tool
- [ ] Add troubleshooting guides
- [ ] Create installation videos/tutorials

## User Experience

- [ ] Add interactive mode for installation
- [ ] Create TUI for managing tools
- [ ] Add progress indicators for long-running tasks
- [ ] Implement logging system

## Testing

- [ ] Create automated tests for installation
- [ ] Test in CI environments
- [ ] Create test VMs for different platforms

## Security

- [ ] Verify all source code before building
- [ ] Implement checksum verification
- [ ] Add signature verification for downloads

## Miscellaneous

- [ ] Refactor common functionality
- [ ] Improve error messages
- [ ] Add uninstall functionality
