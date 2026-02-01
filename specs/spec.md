# Devbox Specification

A CLI tool for managing isolated, authenticated development containers.

## Overview

Devbox spins up lightweight Docker containers pre-configured with GitHub CLI and Claude Code, cloned to a specified repository, with Nix-based development environments. Users authenticate once; credentials persist across container lifecycles.

## Platforms

- macOS (Intel and Apple Silicon)
- Linux (x86_64)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Host Machine                                                │
│                                                             │
│  ┌─────────────┐    ┌─────────────────────────────────────┐ │
│  │ devbox CLI  │───▶│ Docker Daemon                       │ │
│  └─────────────┘    │                                     │ │
│                     │  ┌───────────┐  ┌───────────┐       │ │
│  ┌─────────────┐    │  │ container │  │ container │  ...  │ │
│  │ credentials │◀───│  │ instance1 │  │ instance2 │       │ │
│  │ volume      │    │  └───────────┘  └───────────┘       │ │
│  └─────────────┘    └─────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Components

1. **devbox CLI** - Command-line interface written in Bash
2. **devbox-base image** - Lightweight Docker image with gh, claude, nix
3. **devbox-credentials volume** - Docker volume storing GitHub and Claude auth
4. **Container instances** - Ephemeral workspaces cloned from repos

---

## Credential Management

### Problem Addressed

On macOS, Claude Code stores OAuth credentials in the **macOS Keychain**, not in filesystem files. When bind-mounting `~/.claude` from macOS into a Linux container, the credentials aren't there—the container can't access Keychain. Additionally, multiple containers writing to the same credential files causes race conditions.

### Solution

Run authentication **inside a Linux container** during `devbox init`. Linux Claude Code stores credentials in `~/.claude/.credentials.json`. Store this in a Docker volume, mount read-only into work containers.

For Bedrock mode: OAuth is disabled entirely. Authentication is purely through AWS credentials, so only AWS config needs to be shared.

### Credential Volume Structure

```
devbox-credentials/
├── gh/
│   └── hosts.yml                 # GitHub CLI OAuth token
├── claude/
│   ├── .credentials.json         # Claude OAuth tokens (for non-Bedrock)
│   ├── settings.json             # Claude settings
│   └── settings.local.json       # Local overrides
└── aws/
    ├── config                    # AWS CLI config (profiles, regions)
    └── credentials               # AWS access keys
```

### Claude Credential Format

When authenticated via OAuth, `~/.claude/.credentials.json` contains:

```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-...",
    "refreshToken": "sk-ant-ort01-...",
    "expiresAt": 1748658860401,
    "scopes": ["user:inference", "user:profile"]
  }
}
```

### Initialization Flow

```
devbox init
  ├── Create devbox-credentials volume (if not exists)
  ├── Run ephemeral LINUX container with volume mounted read-write
  │   ├── gh auth login --web
  │   ├── claude (triggers OAuth flow, writes to .credentials.json)
  │   └── Prompt for AWS credentials / import from host ~/.aws
  └── Mark initialization complete
```

### Auth Modes

Devbox supports two Claude authentication modes:

**Mode 1: Claude OAuth (default)**
- User authenticates via browser OAuth during `devbox init`
- Credentials stored in volume at `/claude/.credentials.json`
- Works with Claude Pro/Max subscription

**Mode 2: AWS Bedrock**
- No Claude OAuth needed
- Set `CLAUDE_CODE_USE_BEDROCK=1` and `AWS_REGION`
- Auth handled entirely by AWS credentials
- Specify profile at container creation: `--aws-profile bedrock-prod`

### Container Credential Mounting

Containers mount the credentials volume read-only:

```bash
-v devbox-credentials:/devbox-credentials:ro
```

Environment variables point tools to credential files:

| Tool       | Environment Variables                                         |
|------------|---------------------------------------------------------------|
| GitHub CLI | `GH_CONFIG_DIR=/devbox-credentials/gh`                        |
| Claude     | `CLAUDE_CONFIG_DIR=/devbox-credentials/claude`                |
| AWS CLI    | `AWS_CONFIG_FILE=/devbox-credentials/aws/config`              |
|            | `AWS_SHARED_CREDENTIALS_FILE=/devbox-credentials/aws/credentials` |

### Bedrock Configuration

For Bedrock mode, containers receive these additional environment variables:

```bash
CLAUDE_CODE_USE_BEDROCK=1
AWS_REGION=us-east-1              # Required - Claude Code ignores .aws/config for region
AWS_PROFILE=bedrock-prod          # From --aws-profile flag
```

Note: When `CLAUDE_CODE_USE_BEDROCK=1` is set, Claude Code disables `/login` and `/logout` commands—authentication is handled entirely through AWS credentials.

### AWS Profile Selection

Specified at container creation:

```bash
devbox create myinstance git@github.com:org/repo.git --aws-profile bedrock-prod
```

For OAuth mode (default): Sets `AWS_PROFILE` for any AWS SDK usage in the project.
For Bedrock mode: Sets `AWS_PROFILE` and enables `CLAUDE_CODE_USE_BEDROCK=1`.

---

## Base Image

### Requirements

- Minimal footprint
- Nix package manager installed
- GitHub CLI (`gh`)
- Claude Code (`claude`)
- Git, bash, curl, ca-certificates

### Base

Debian bookworm-slim. Nix installed via Determinate Systems installer for multi-user mode.

### Dockerfile Outline

```dockerfile
FROM debian:bookworm-slim

# Install minimal dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    xz-utils \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Nix (Determinate Systems installer)
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install linux --init none --no-confirm

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for Claude Code)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code
# Note: Anthropic recommends native installer, but npm works reliably in containers
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user
RUN useradd -m -s /bin/bash devbox
USER devbox
WORKDIR /home/devbox

# Entrypoint handles repo clone and nix shell
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

### Entrypoint Script

```bash
#!/bin/bash
set -e

REPO_URL="${DEVBOX_REPO_URL}"
REPO_DIR="/workspace"

# Clone repository if not already present
if [ ! -d "$REPO_DIR/.git" ]; then
    git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

# Verify Nix configuration exists
if [ ! -f "flake.nix" ] && [ ! -f "shell.nix" ]; then
    echo "ERROR: No flake.nix or shell.nix found in repository."
    echo "Devbox requires a Nix configuration for development dependencies."
    exit 1
fi

# Enter Nix shell
if [ -f "flake.nix" ]; then
    exec nix develop --command bash
else
    exec nix-shell --command bash
fi
```

---

## CLI Interface

### Commands

#### `devbox init`

One-time setup. Authenticates GitHub CLI and Claude Code (if not using Bedrock), stores credentials in Docker volume.

```bash
devbox init
devbox init --bedrock  # Skip Claude OAuth, only configure GitHub + AWS
```

Options:
- `--import-aws` - Import existing AWS credentials from `~/.aws` on host
- `--bedrock` - Configure for Bedrock mode (skips Claude OAuth)

#### `devbox create <name> <repo-url>`

Create and start a new container instance.

```bash
devbox create myproject git@github.com:org/repo.git
devbox create myproject git@github.com:org/repo.git --port 3000:3000 --port 8080:8080
devbox create myproject git@github.com:org/repo.git --bedrock --aws-profile bedrock-prod
```

Options:
- `--port, -p <host:container>` - Port mapping (repeatable)
- `--bedrock` - Use AWS Bedrock for Claude (sets `CLAUDE_CODE_USE_BEDROCK=1`)
- `--aws-profile <profile>` - AWS profile name (required with `--bedrock`)

#### `devbox list`

List all devbox containers with status.

```bash
devbox list
```

Output:
```
NAME          ID            STATUS    REPO                              PORTS            MODE
myproject     a1b2c3d4      running   git@github.com:org/repo.git       3000:3000        bedrock
experiment    e5f6g7h8      running   git@github.com:org/other.git      -                oauth
```

#### `devbox attach <name-or-id>`

Attach to a running container's shell.

```bash
devbox attach myproject
devbox attach a1b2c3d4
```

Attaches to the bash session inside the Nix shell. Detach with `Ctrl+P, Ctrl+Q` (standard Docker detach sequence).

#### `devbox stop <name-or-id>`

Stop a container (keeps state).

```bash
devbox stop myproject
```

#### `devbox start <name-or-id>`

Start a stopped container.

```bash
devbox start myproject
```

#### `devbox rm <name-or-id>`

Remove a container. Must be stopped first, or use `--force`.

```bash
devbox rm myproject
devbox rm --force myproject
```

#### `devbox logs <name-or-id>`

View container logs.

```bash
devbox logs myproject
devbox logs -f myproject  # follow
```

#### `devbox exec <name-or-id> <command>`

Execute a command in a running container.

```bash
devbox exec myproject gh pr list
devbox exec myproject claude --version
```

#### `devbox ports <name-or-id>`

Show port mappings for a container.

```bash
devbox ports myproject
```

---

## Container Lifecycle

### States

```
          create
    ┌────────────────┐
    │                ▼
    │         ┌──────────┐
    │         │ running  │◀─────┐
    │         └────┬─────┘      │
    │              │            │
    │         stop │      start │
    │              ▼            │
    │         ┌──────────┐      │
    │         │ stopped  │──────┘
    │         └────┬─────┘
    │              │
    │           rm │
    │              ▼
    └────────▶ (removed)
```

### Detach Behavior

When user detaches (`Ctrl+P, Ctrl+Q`), the container continues running. The shell session persists; reattaching reconnects to the same session.

### Persistence

Containers are disposable. The `/workspace` directory (cloned repo) exists only within the container. Stopping preserves state; removing destroys it.

Future enhancement: configuration file to define containers that auto-start on host boot.

---

## Nix Integration

### Configuration (Optional)

Repositories can optionally contain a Nix configuration for project-specific tools:
- `flake.nix` (preferred)
- `shell.nix` (legacy)

**Behavior:**
- If `flake.nix` exists → enters `nix develop` with project-specific tools
- If `shell.nix` exists → enters `nix-shell` with project-specific tools
- If neither exists → drops into basic bash shell with devbox base tools (git, gh, claude)

This makes devbox accessible to projects that don't use Nix while still providing full Nix integration for those that do.

### Flake Example

```nix
{
  description = "My project dev environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs_20
            yarn
            postgresql
          ];

          shellHook = ''
            echo "Development environment loaded"
          '';
        };
      });
}
```

### shell.nix Example

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    nodejs_20
    yarn
    postgresql
  ];

  shellHook = ''
    echo "Development environment loaded"
  '';
}
```

---

## Implementation Plan

### Phase 1: Core Functionality

1. Base Docker image
2. Credential volume initialization (`devbox init`)
3. Container create/list/attach/stop/start/rm
4. Basic port mapping

### Phase 2: Polish

1. Improved error messages
2. Shell completion (bash)
3. `devbox exec` command
4. Logs command

### Phase 3: Team Features

1. Documentation
2. Configurable base image registry
3. Startup configuration file

---

## Open Questions (Resolved)

1. **Claude Code credential storage** - ✅ Resolved. On Linux, credentials are stored in `~/.claude/.credentials.json`. On macOS, they go to Keychain (which is why bind mounts from macOS don't work). Running init inside a Linux container solves this.

2. **Claude Code installation** - ✅ Resolved. Anthropic says npm is "deprecated" but it still works. Use `npm install -g @anthropic-ai/claude-code`. Requires Node.js 18+.

3. **Bedrock authentication** - ✅ Resolved. Set `CLAUDE_CODE_USE_BEDROCK=1` and `AWS_REGION`. Uses standard AWS credential chain. OAuth commands (`/login`, `/logout`) are disabled in Bedrock mode.

4. **Nix in Docker** - Needs testing. Determinate Systems installer should work, but may need adjustments for containerized use.

5. **Token refresh** - Claude OAuth tokens have `expiresAt` and `refreshToken` fields. Claude Code handles refresh automatically. If tokens become invalid, user needs to re-run `devbox init`.

---

## File Structure

```
devbox/
├── bin/
│   └── devbox              # Main CLI script (bash)
├── docker/
│   ├── Dockerfile          # Base image definition
│   └── entrypoint.sh       # Container entrypoint
├── completions/
│   └── devbox.bash         # Bash completion
├── install.sh              # Installation script
└── README.md
```

---

## Example Session

```bash
# First-time setup (Bedrock mode - skip Claude OAuth)
$ devbox init --bedrock --import-aws
Creating credentials volume...
Starting GitHub CLI authentication...
  → Opening browser for GitHub OAuth...
  ✓ Authenticated as @chrissmith
Importing AWS credentials from ~/.aws...
  ✓ Imported 3 profiles: default, bedrock-prod, bedrock-dev
Initialization complete (Bedrock mode).

# Create a new development container
$ devbox create mapquest git@github.com:system1/mapquest.git \
    --port 3000:3000 \
    --bedrock \
    --aws-profile bedrock-prod
Cloning repository...
Entering Nix shell...
Container 'mapquest' (f8a3b2c1) created and running.

# List containers
$ devbox list
NAME       ID         STATUS    REPO                                PORTS       MODE
mapquest   f8a3b2c1   running   git@github.com:system1/mapquest     3000:3000   bedrock

# Attach to container
$ devbox attach mapquest
[nix-shell:/workspace]$ node --version
v20.11.0
[nix-shell:/workspace]$ gh pr list
Showing 3 open pull requests...
[nix-shell:/workspace]$ claude "explain this codebase"
...

# Detach with Ctrl+P, Ctrl+Q
$ # back on host

# Stop and remove
$ devbox stop mapquest
$ devbox rm mapquest
```

### Alternative: OAuth Mode (Claude Pro/Max subscription)

```bash
# First-time setup (OAuth mode)
$ devbox init
Creating credentials volume...
Starting GitHub CLI authentication...
  → Opening browser for GitHub OAuth...
  ✓ Authenticated as @chrissmith
Starting Claude Code authentication...
  → Opening browser for Claude OAuth...
  ✓ Authenticated
Initialization complete.

# Create container (no --bedrock flag)
$ devbox create myproject git@github.com:org/repo.git --port 3000:3000
```
