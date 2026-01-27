# Devbox

A CLI tool for managing isolated, authenticated development containers.

## Overview

Devbox spins up lightweight Docker containers pre-configured with GitHub CLI and Claude Code, cloned to a specified repository, with Nix-based development environments. Users authenticate once; credentials persist across container lifecycles.

## Quick Start

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled
- Docker (Docker Desktop or alternatives like Colima on macOS)

### Development Setup

1. **Enter the development environment:**
   ```bash
   nix develop
   ```

2. **Verify the setup:**
   ```bash
   devbox help          # Test the CLI
   devbox-test          # Run basic tests
   devbox-lint          # Check code quality
   ```

3. **Initialize devbox (one-time setup):**
   ```bash
   ./bin/devbox init --bedrock --import-aws                    # For AWS Bedrock mode (all SSO profiles)
   ./bin/devbox init --bedrock --import-aws --aws-profile prod # For AWS Bedrock mode (specific profile)
   # OR
   ./bin/devbox init                                           # For Claude OAuth mode
   ```

4. **Create your first development container:**
   ```bash
   ./bin/devbox create myproject git@github.com:org/repo.git
   ```

### Development Workflow

The Nix development shell provides:

- **Code Quality**: `shellcheck` for bash linting, `shfmt` for formatting
- **Testing**: Comprehensive test suite in `tests/`
- **Docker Integration**: Build and manage devbox containers
- **Development Tools**: Git, GitHub CLI, Node.js, and more

**Available commands in the dev shell:**
```bash
devbox-test      # Run the test suite
devbox-lint      # Lint all bash scripts
devbox-format    # Format all bash scripts
devbox-build     # Build the Docker base image
```

## Usage

### Commands

- `devbox init [--bedrock] [--import-aws] [--aws-profile <name>]` - One-time setup: authenticate GitHub CLI and Claude Code
- `devbox create <name> <repo>` - Create and start a new container instance
- `devbox list` - List all devbox containers with status
- `devbox attach <name|id>` - Attach to a running container's shell
- `devbox stop <name|id>` - Stop a container (keeps state)
- `devbox start <name|id>` - Start a stopped container
- `devbox rm <name|id>` - Remove a container

### Authentication Modes

**Claude OAuth Mode (default):**
```bash
devbox init
devbox create myapp git@github.com:org/repo.git
```

**AWS Bedrock Mode:**
```bash
# Authenticate all SSO profiles
devbox init --bedrock --import-aws
devbox create myapp git@github.com:org/repo.git --bedrock --aws-profile prod

# Authenticate specific SSO profile only
devbox init --bedrock --import-aws --aws-profile prod
devbox create myapp git@github.com:org/repo.git --bedrock --aws-profile prod
```

## Development

### Project Structure

```
devbox/
├── bin/
│   └── devbox              # Main CLI script (bash)
├── docker/
│   ├── Dockerfile          # Base image definition
│   ├── entrypoint.sh       # Container entrypoint
│   └── init-credentials.sh # Credential initialization
├── tests/
│   ├── test_cli_basic.sh   # Basic CLI tests
│   ├── test_init.sh        # Init command tests
│   ├── test_create.sh      # Create command tests
│   └── ...                 # Individual command tests
├── specs/
│   └── spec.md            # Detailed specification
├── flake.nix              # Nix development environment
└── README.md
```

### Testing

Run the comprehensive test suite:
```bash
# Run all basic tests
./tests/test_cli_basic.sh

# Run specific command tests
./tests/test_init.sh
./tests/test_create.sh
./tests/test_attach.sh
# ... etc
```

### Meta Development

This project supports "developing devbox inside of devbox" - using devbox itself as the development environment:

1. **Set up your devbox repo in a devbox container:**
   ```bash
   devbox create devbox-dev git@github.com:your-org/devbox.git
   devbox attach devbox-dev
   ```

2. **Inside the container, you'll have access to:**
   - Nix development environment with all tools
   - Docker-in-Docker for testing container operations
   - Full development workflow including testing and building

### Contributing

1. **Code Quality**: All bash scripts should pass `shellcheck` and be formatted with `shfmt`
2. **Testing**: Add tests for new commands in `tests/test_<command>.sh`
3. **Documentation**: Update help text and examples for new features

## Architecture

See [specs/spec.md](specs/spec.md) for detailed architecture and implementation notes.

## License

[Add license information]