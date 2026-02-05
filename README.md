# Devbox

[![CI](https://github.com/testaco/devbox/workflows/CI/badge.svg)](https://github.com/testaco/devbox/actions/workflows/ci.yml)
[![Website](https://github.com/testaco/devbox/actions/workflows/deploy-pages.yml/badge.svg)](https://testaco.github.io/devbox/)

A CLI tool for managing isolated, authenticated development containers.

## Overview

Devbox spins up lightweight Docker containers pre-configured with GitHub CLI and Claude Code, cloned to a specified repository, with Nix-based development environments. Users authenticate once; credentials persist across container lifecycles.

## Security Warning

**This is research/work in progress. Known security issues exist.**

- Do NOT use this tool fully unattended in production environments
- Containers have access to sensitive credentials (GitHub tokens, AWS credentials, Claude API keys)
- The project is under active development and has not undergone security review
- Use only in controlled development environments where you understand the risks

If you discover security issues, please report them responsibly via GitHub issues.

## Security Features

Devbox includes several security features to minimize the attack surface:

**Docker-in-Docker is opt-in**: By default, containers do not have Docker access. Use `--enable-docker` to enable Docker-in-Docker functionality when needed. When enabled, minimal Linux capabilities are used instead of full `--privileged` mode.

**Sudo is disabled by default**: The devbox user has no sudo access unless explicitly requested. Use `--sudo nopass` for passwordless sudo or `--sudo password` to set a password during container creation.

**No TCP socket for inner Docker**: When Docker-in-Docker is enabled, the inner Docker daemon only listens on a Unix socket, not TCP, preventing network-based attacks.

**Secrets are stored securely**: Secrets are stored with restricted file permissions (600) and mounted into containers via Docker volumes, never exposed as environment variables visible in `docker inspect`.

**Network egress control**: Containers use the `standard` egress profile by default, which allows access only to common development services (package managers, git hosts, cloud APIs) and blocks known data exfiltration vectors. Use `--egress strict` for tighter control or `--egress airgapped` for complete network isolation.

## Installation

### Prerequisites

- Docker (Docker Desktop, Colima on macOS, or native Docker on Linux)
- Bash shell

### Quick Install

```bash
# Clone the repository
git clone git@github.com:your-org/devbox.git
cd devbox

# Install system-wide (requires sudo)
sudo ./install.sh

# Or install to user directory (no sudo needed)
./install.sh --prefix ~/.local
```

### Installation Options

```bash
# See all options
./install.sh --help

# Install without building Docker image (build later)
./install.sh --prefix ~/.local --skip-image

# Dry run - see what would be installed
./install.sh --dry-run

# Uninstall
./install.sh --prefix ~/.local --uninstall
```

### Post-Installation

1. **Add to PATH** (if using `--prefix ~/.local`):
   ```bash
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   ```

2. **Enable bash completion** (optional):
   ```bash
   # For user installation
   source ~/.local/share/bash-completion/completions/devbox

   # To enable permanently, add to ~/.bashrc:
   echo 'source ~/.local/share/bash-completion/completions/devbox' >> ~/.bashrc
   ```

3. **Initialize devbox**:
   ```bash
   devbox init                           # For Claude OAuth mode
   # OR
   devbox init --bedrock --import-aws    # For AWS Bedrock mode
   ```

## Quick Start

```bash
# 1. Install devbox
git clone git@github.com:your-org/devbox.git
cd devbox
./install.sh --prefix ~/.local

# 2. Initialize (one-time) - sets up credential volumes
devbox init --bedrock --import-aws             # AWS Bedrock mode (recommended)
# OR
devbox init                                    # OAuth mode (manual token setup)

# 3. Store your GitHub token (one-time)
export GITHUB_TOKEN="ghp_xxx..."
devbox secrets add github-token --from-env GITHUB_TOKEN

# 4a. For OAuth mode only: Get and store Claude Code token (one-time)
claude setup-token                             # Follow prompts, then:
devbox secrets add claude-oauth-token --from-env CLAUDE_CODE_OAUTH_TOKEN

# 4b. Create a container
# OAuth mode:
devbox create myproject org/repo \
  --github-secret github-token \
  --claude-code-secret claude-oauth-token

# Bedrock mode:
devbox create myproject org/repo \
  --github-secret github-token \
  --bedrock --aws-profile prod

# 5. Start working
devbox attach myproject
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `devbox init` | One-time setup: authenticate Claude Code and AWS |
| `devbox create <name> <repo>` | Create and start a new container instance |
| `devbox list` | List all devbox containers with status |
| `devbox attach <name\|id>` | Attach to a running container's shell |
| `devbox stop <name\|id>` | Stop a container (keeps state) |
| `devbox start <name\|id>` | Start a stopped container |
| `devbox rm <name\|id>` | Remove a container |
| `devbox logs <name\|id>` | View container logs |
| `devbox exec <name\|id> <cmd>` | Execute a command in a running container |
| `devbox ports <name\|id>` | Show port mappings for a container |
| `devbox secrets <subcommand>` | Manage secrets (add, remove, list, path, import-env) |
| `devbox network <subcommand>` | Manage network egress rules (show, allow, block, logs, reset) |
| `devbox help` | Show help message |

### Secrets Management

Devbox uses secure secret storage for sensitive credentials like GitHub tokens. Secrets are stored with restricted permissions and injected into containers via Docker volumes (never as environment variables).

```bash
# Add a secret from an environment variable
export GITHUB_TOKEN="ghp_xxx..."
devbox secrets add github-token --from-env GITHUB_TOKEN

# Or import directly from an existing env var
devbox secrets import-env GITHUB_TOKEN

# List stored secrets
devbox secrets list

# Remove a secret
devbox secrets remove github-token

# Show secrets storage path
devbox secrets path
```

### Network Egress Control

Devbox controls outbound network access with security profiles:

| Profile | Description |
|---------|-------------|
| `permissive` | All egress allowed (no restrictions) |
| `standard` | Dev-friendly allowlist - package managers, git hosts, cloud APIs (default) |
| `strict` | Minimal egress - only explicit allowlist, blocks everything else |
| `airgapped` | No network access - fully isolated container |

```bash
# Create container with standard profile (default)
devbox create myapp org/repo --github-secret github-token --claude-code-secret claude-oauth-token

# Create container with strict egress
devbox create myapp org/repo --github-secret github-token --claude-code-secret claude-oauth-token \
  --egress strict --allow-domain api.example.com

# Create airgapped container
devbox create myapp org/repo --github-secret github-token --claude-code-secret claude-oauth-token \
  --egress airgapped

# View egress rules for a container
devbox network show myapp

# Add an allowed domain at runtime
devbox network allow myapp --domain api.example.com

# Block a domain
devbox network block myapp --domain evil.com

# View egress logs
devbox network logs myapp --blocked-only
```

The `standard` profile includes:
- **Allowed ports**: 53 (DNS), 22 (SSH), 80 (HTTP), 443 (HTTPS), 9418 (Git)
- **Allowed domains**: github.com, npmjs.org, pypi.org, crates.io, cache.nixos.org, amazonaws.com, anthropic.com, and more
- **Blocked domains**: pastebin.com, transfer.sh, ngrok.io (data exfiltration vectors)

### Init Options

| Option | Description |
|--------|-------------|
| `--bedrock` | Skip Claude OAuth, configure for AWS Bedrock mode |
| `--import-aws` | Import existing AWS credentials from ~/.aws |
| `--aws-profile <name>` | Specific AWS profile to authenticate |

### Create Options

| Option | Description |
|--------|-------------|
| `--github-secret <name>` | GitHub token secret (required) |
| `--claude-code-secret <name>` | Claude Code OAuth token secret (required for non-Bedrock mode) |
| `--port, -p <host:container>` | Port mapping (can be used multiple times) |
| `--bedrock` | Use AWS Bedrock for Claude (no Claude OAuth needed) |
| `--aws-profile <profile>` | AWS profile name for Bedrock |
| `--enable-docker` | Enable Docker-in-Docker functionality (disabled by default for security) |
| `--sudo <mode>` | Enable sudo access: `nopass` (passwordless) or `password` (prompts for password) |
| `--egress <profile>` | Network egress profile: `permissive`, `standard` (default), `strict`, or `airgapped` |
| `--allow-domain <domain>` | Additional allowed domain (can be used multiple times) |
| `--block-domain <domain>` | Block specific domain (can be used multiple times) |
| `--allow-ip <ip/cidr>` | Additional allowed IP/CIDR (can be used multiple times) |
| `--block-ip <ip/cidr>` | Block specific IP/CIDR (can be used multiple times) |
| `--allow-port <port>` | Additional allowed port (can be used multiple times) |

### Rm Options

| Option | Description |
|--------|-------------|
| `--force, -f` | Force remove a running container |
| `-a` | Remove all devbox containers (with confirmation) |
| `-af, -fa` | Remove all devbox containers including running ones |

### Logs Options

| Option | Description |
|--------|-------------|
| `-f, --follow` | Follow log output (like `tail -f`) |

### Authentication Modes

**Claude OAuth Mode:**
```bash
# One-time setup
devbox init

# Store your GitHub token securely
export GITHUB_TOKEN="ghp_xxx..."
devbox secrets add github-token --from-env GITHUB_TOKEN

# Get and store Claude Code OAuth token
claude setup-token                    # Follow prompts
devbox secrets add claude-oauth-token --from-env CLAUDE_CODE_OAUTH_TOKEN

# Create container (requires both secrets)
devbox create myapp org/repo \
  --github-secret github-token \
  --claude-code-secret claude-oauth-token
```

**AWS Bedrock Mode (recommended):**
```bash
# One-time setup with AWS credentials
devbox init --bedrock --import-aws

# Store your GitHub token
devbox secrets import-env GITHUB_TOKEN

# Create container (no Claude secret needed)
devbox create myapp org/repo \
  --github-secret github-token \
  --bedrock --aws-profile prod
```

### Common Workflows

**Create a development container with port forwarding:**
```bash
# OAuth mode
devbox create webapp org/my-web-app \
  --github-secret github-token \
  --claude-code-secret claude-oauth-token \
  -p 3000:3000 -p 8080:8080

# Bedrock mode
devbox create webapp org/my-web-app \
  --github-secret github-token \
  --bedrock \
  -p 3000:3000 -p 8080:8080

devbox attach webapp
```

**Check container status and logs:**
```bash
devbox list
devbox logs webapp -f
devbox ports webapp
```

**Execute commands without attaching:**
```bash
devbox exec webapp gh pr list
devbox exec webapp npm test
```

**Clean up containers:**
```bash
devbox stop webapp     # Stop but keep state
devbox rm webapp       # Remove (prompts for confirmation)
devbox rm -af          # Remove all containers (force)
```

## Development

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled (optional but recommended)
- Docker (Docker Desktop or alternatives like Colima on macOS)

### Getting Started

1. **Clone and enter the development environment:**
   ```bash
   git clone git@github.com:your-org/devbox.git
   cd devbox
   nix develop    # If using Nix
   ```

2. **Set up pre-commit hooks:**
   ```bash
   git config core.hooksPath .githooks
   ```

3. **Verify the setup:**
   ```bash
   ./bin/devbox help    # Test the CLI
   devbox-test          # Run basic tests (in Nix shell)
   devbox-lint          # Check code quality (in Nix shell)
   ```

4. **Initialize devbox (one-time setup):**
   ```bash
   ./bin/devbox init                           # Claude OAuth mode
   # OR
   ./bin/devbox init --bedrock --import-aws    # AWS Bedrock mode
   ```

5. **Store your secrets:**
   ```bash
   # GitHub token (always required)
   export GITHUB_TOKEN="ghp_xxx..."
   ./bin/devbox secrets add github-token --from-env GITHUB_TOKEN

   # For OAuth mode: get Claude token first
   claude setup-token  # Follow prompts
   ./bin/devbox secrets add claude-oauth-token --from-env CLAUDE_CODE_OAUTH_TOKEN
   ```

6. **Create your first development container:**
   ```bash
   # OAuth mode
   ./bin/devbox create myproject org/repo \
     --github-secret github-token \
     --claude-code-secret claude-oauth-token

   # Bedrock mode
   ./bin/devbox create myproject org/repo \
     --github-secret github-token \
     --bedrock --aws-profile prod
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

### Project Structure

```
devbox/
├── bin/
│   └── devbox              # Main CLI script (bash)
├── completions/
│   └── devbox.bash         # Bash tab-completion
├── docker/
│   ├── Dockerfile          # Base image definition
│   ├── entrypoint.sh       # Container entrypoint
│   └── init-credentials.sh # Credential initialization
├── .githooks/
│   └── pre-commit          # Pre-commit hook (runs tests)
├── lib/
│   └── progress.sh         # Progress indicator library
├── tests/
│   ├── test_cli_basic.sh   # Basic CLI tests
│   ├── test_init.sh        # Init command tests
│   ├── test_create.sh      # Create command tests
│   ├── test_secrets.sh     # Secrets management tests
│   └── ...                 # Individual command tests
├── specs/
│   └── spec.md             # Detailed specification
├── base-flake/             # Template Nix flake for containers
├── install.sh              # Installation script
├── flake.nix               # Nix development environment
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
   # OAuth mode
   devbox create devbox-dev your-org/devbox \
     --github-secret github-token \
     --claude-code-secret claude-oauth-token

   # Bedrock mode
   devbox create devbox-dev your-org/devbox \
     --github-secret github-token \
     --bedrock

   devbox attach devbox-dev
   ```

2. **Inside the container, you'll have access to:**
   - Nix development environment with all tools
   - Docker-in-Docker for testing container operations
   - Full development workflow including testing and building

### Contributing

1. **Code Quality**: All bash scripts should pass `shellcheck` and be formatted with `shfmt`
2. **Testing**: Add tests for new commands in `tests/test_<command>.sh`
3. **Pre-commit Hooks**: Run `git config core.hooksPath .githooks` to enable
4. **Documentation**: Update help text and examples for new features

## Architecture

See [specs/spec.md](specs/spec.md) for detailed architecture and implementation notes.

## Website

The devbox marketing website is available at **https://testaco.github.io/devbox/**

The website is built with Vite + React and automatically deployed to GitHub Pages when changes are pushed to the `web/` directory.

### Local Development

```bash
cd web
pnpm install
pnpm dev
```

## License

[Add license information]