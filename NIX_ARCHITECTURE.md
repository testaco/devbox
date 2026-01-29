# Devbox Nix Architecture

This document describes the new Nix-based architecture for Devbox, which provides a minimal Docker image with on-demand tool installation via Nix flakes.

## Overview

The architecture consists of four main components:

1. **Minimal Dockerfile** - Debian base with Nix and Docker daemon only
2. **Bootstrap Entrypoint** - Installs tools on-demand and clones repo
3. **Base Flake** - Platform layer providing core dev tools
4. **Template Flake** - Project starter for team repositories

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│ Dockerfile (minimal)                                    │
│  • debian:bookworm-slim                                 │
│  • Nix (single-user, flakes enabled)                    │
│  • Docker daemon (for DinD)                             │
│  • NO git, gh, claude, aws, nodejs, etc.                │
└─────────────────────────────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────────┐
│ Entrypoint (bootstrap sequence)                         │
│  1. Read GITHUB_TOKEN from env or secret file           │
│  2. Exit with error if no token                         │
│  3. Export GITHUB_TOKEN for gh                          │
│  4. nix profile install nixpkgs#gh                      │
│  5. gh repo clone $REPO workspace                       │
│  6. cd workspace && exec nix develop                    │
└─────────────────────────────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────────┐
│ Project flake.nix (from template)                       │
│  • inputsFrom: devbox base flake                        │
│  • Project-specific packages: nodejs, python, etc.      │
└─────────────────────────────────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────────┐
│ Base flake (platform)                                   │
│  • git, gh, claude, aws, jq, vim, shellcheck, etc.      │
│  • Shared across all projects                           │
└─────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Dockerfile (~40 lines)

**Location:** `docker/Dockerfile`

**What it contains:**
- `debian:bookworm-slim` base image
- Minimal dependencies: `curl`, `ca-certificates`, `xz-utils`, `sudo`
- Nix installation (single-user mode with flakes enabled)
- Docker daemon (for DinD capability)
- User setup: `devbox` user (UID 1000) with passwordless sudo

**What it does NOT contain:**
- No git, gh, awscli, nodejs, claude-code
- No language runtimes
- No development tools

All development tools come from Nix via the base flake.

### 2. Entrypoint Script

**Location:** `docker/entrypoint.sh`

**Bootstrap sequence:**

```bash
# 1. Read GitHub token
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$GITHUB_TOKEN" ] && [ -f "/run/secrets/github_token" ]; then
    GITHUB_TOKEN=$(cat /run/secrets/github_token)
fi
[[ -z "$GITHUB_TOKEN" ]] && error_and_exit

# 2. Export token (gh respects GITHUB_TOKEN automatically)
export GITHUB_TOKEN

# 3. Set up Docker (DinD or host socket)
# ... Docker setup code ...

# 4. Copy Claude/AWS credentials from volume
# ... credential setup ...

# 5. Install gh via Nix
nix profile install nixpkgs#gh

# 6. Clone repository
gh repo clone "$REPO" workspace

# 7. Enter Nix dev shell
cd workspace
exec nix develop
```

**Key features:**
- No GitHub OAuth needed (uses token directly)
- Tools installed on-demand (cached after first run)
- Hands off to project's flake.nix

### 3. Base Flake

**Location:** `base-flake/flake.nix`

**Purpose:** Provides core platform tools shared across all projects.

**Inputs:**
```nix
nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
flake-utils.url = "github:numtide/flake-utils";
claude-code.url = "github:sadjow/claude-code-nix";
```

**Provides:**
- **Shell essentials:** bash, coreutils, findutils, gnugrep, gnused
- **Git/GitHub:** git, gh
- **AI:** claude-code (from external flake)
- **AWS:** awscli2
- **Utilities:** curl, jq, yq-go, tree, htop, wget
- **Editors:** vim, nano

**Exports:**
- `lib.basePackages` - for advanced composition
- `templates.default` - project template
- `devShells.default` - standalone dev shell

**Usage:**
```bash
# Use the base flake directly (for testing)
nix develop github:system1/devbox?dir=base-flake

# Use the template
nix flake init -t github:system1/devbox?dir=base-flake
```

### 4. Template Flake

**Location:** `base-flake/template/flake.nix`

**Purpose:** Starter template for project repositories.

**Structure:**
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devbox.url = "github:system1/devbox?dir=base-flake";
  };

  outputs = { self, nixpkgs, devbox }:
    devShells.default = pkgs.mkShell {
      # Inherit base platform
      inputsFrom = [ devbox.devShells.${system}.default ];

      # Add project-specific tools
      buildInputs = with pkgs; [
        # nodejs_20
        # python311
        # terraform
      ];

      shellHook = ''
        # Project-specific setup
      '';
    };
}
```

**Features:**
- Inherits all base platform tools via `inputsFrom`
- Project teams add their specific dependencies
- Updates via `nix flake update devbox`

## GitHub Token Authentication

### Why Tokens Instead of OAuth?

**Old approach:**
- `devbox init` runs container with `gh auth login --web`
- Stores OAuth tokens in credential volume
- Complex setup, requires browser interaction

**New approach:**
- User creates fine-grained token once
- Pass token via env var or secret file
- `gh` uses `GITHUB_TOKEN` automatically (no login needed)
- Simpler, more secure (scoped to specific repos)

### Creating a Token

1. Go to GitHub → Settings → Developer settings → Fine-grained tokens
2. Click "Generate new token"
3. **Repository access:** "Only select repositories" → pick your repo
4. **Permissions:**
   - Metadata: Read (required by GitHub)
   - Contents: Read (for cloning)
   - Contents: Read and Write (if pushing)
5. **Expiration:** Set reasonable expiry (e.g., 90 days)

### Using the Token

**Option A: Environment variable (simpler)**
```bash
export GITHUB_TOKEN="github_pat_xxx..."
devbox create myapp org/repo
```

**Option B: Secret file (more secure)**
```bash
echo "github_pat_xxx..." > ~/.secrets/github_token
chmod 600 ~/.secrets/github_token

docker run \
  -v ~/.secrets/github_token:/run/secrets/github_token:ro \
  -e DEVBOX_REPO="org/repo" \
  devbox-base:latest
```

### Token Security

**Benefits:**
- Scoped to specific repositories (not all repos)
- Minimal permissions (read-only by default)
- Expires automatically
- No OAuth app with broad access
- No tokens visible in process list (when using secret file)

## Claude and AWS Credentials

While GitHub uses tokens, Claude and AWS still use the credential volume approach:

**Credential volume:** `devbox-credentials`
```
devbox-credentials/
├── claude/
│   ├── .credentials.json    # OAuth tokens
│   └── settings.json         # User settings
└── aws/
    ├── config                # AWS config
    └── credentials           # AWS credentials
```

**Setup:**
```bash
# Initialize Claude and AWS credentials
devbox init                          # Claude OAuth mode
devbox init --bedrock --import-aws   # Bedrock mode with AWS

# Credentials are mounted read-only in containers
docker run -v devbox-credentials:/devbox-credentials:ro ...
```

## Usage Workflow

### Initial Setup

```bash
# 1. Build the image
docker build -t devbox-base:latest docker/

# 2. Set up Claude/AWS credentials
devbox init

# 3. Create a GitHub token (one time)
# Go to GitHub → Settings → Developer settings → Tokens
# Save token securely

# 4. Export token
export GITHUB_TOKEN="github_pat_xxx..."
```

### Creating a Container

```bash
# Create and start container
devbox create myapp org/repo --port 3000:3000

# Attach to container
devbox attach myapp

# Inside container, all tools are available:
gh pr list
claude --help
aws s3 ls
```

### Project Setup

**Add flake.nix to your project:**
```bash
# Option 1: Use template
nix flake init -t github:system1/devbox?dir=base-flake

# Option 2: Manual (copy template/flake.nix)
cp base-flake/template/flake.nix .

# Customize buildInputs for your project
vim flake.nix  # Add nodejs, python, etc.

# Commit
git add flake.nix flake.lock
git commit -m "Add Nix development environment"
```

## Benefits

### For Operations Teams

1. **Smaller images** - Base image is ~500MB (vs ~2GB with all tools)
2. **Centralized updates** - Update base flake, all projects inherit
3. **Consistent tooling** - Everyone gets same versions of git, gh, claude
4. **Declarative** - Flakes define exactly what's installed

### For Development Teams

1. **Project-specific tools** - Add only what you need (nodejs, python, etc.)
2. **Version pinning** - Lock exact versions with flake.lock
3. **Easy onboarding** - `nix develop` gets full environment
4. **Platform tools included** - git, gh, claude, aws automatically available

### For Security

1. **Scoped GitHub tokens** - One repo, minimal permissions
2. **No long-lived OAuth** - Tokens expire
3. **Secret file support** - Tokens not in env vars
4. **Reproducible** - Nix ensures same tools everywhere

## Migration from Old Architecture

**Old:**
```bash
# All tools in Dockerfile
FROM debian:bookworm-slim
RUN apt-get install gh
RUN npm install -g @anthropic-ai/claude-code
RUN curl aws-cli installer
```

**New:**
```bash
# Minimal Dockerfile
FROM debian:bookworm-slim
RUN install-nix

# Tools come from flakes
# Base flake provides: gh, claude, aws
# Project flake adds: nodejs, python, etc.
```

**Migration steps:**

1. Build new minimal image: `docker build -t devbox-base:latest docker/`
2. Run `devbox init` (sets up Claude/AWS, no GitHub needed)
3. Create GitHub token (one time)
4. Add `flake.nix` to project repos (use template)
5. Create containers with `GITHUB_TOKEN` env var

## Troubleshooting

### "No GitHub token provided"

**Cause:** `GITHUB_TOKEN` not set

**Fix:**
```bash
export GITHUB_TOKEN="github_pat_xxx..."
```

### "Failed to clone repository"

**Cause:** Token lacks access or permissions

**Fix:**
- Verify token has access to repository
- Check token permissions include "Contents: Read"
- Verify repository name format: `owner/repo` (not full URL)

### "No Nix configuration found"

**Cause:** Repository missing `flake.nix`

**Fix:**
```bash
# Initialize flake in your project
nix flake init -t github:system1/devbox?dir=base-flake
git add flake.nix
git commit -m "Add Nix environment"
```

### "nix profile install" fails

**Cause:** Network issues or Nix cache unavailable

**Fix:**
- Check internet connectivity
- Wait and retry (Nix downloads from cache.nixos.org)
- Check proxy settings if behind corporate firewall

## Advanced Usage

### Custom Base Flake

Organizations can fork and customize the base flake:

```nix
# your-org/devbox-platform/flake.nix
{
  outputs = { self, nixpkgs }:
    devShells.default = pkgs.mkShell {
      buildInputs = [
        # Add org-specific tools
        pkgs.gh
        pkgs.terraform
        your-internal-cli
      ];
    };
}
```

Projects reference your fork:
```nix
inputs.devbox.url = "github:your-org/devbox-platform";
```

### Multiple Environments

Projects can define multiple shells:

```nix
devShells = {
  default = # Production environment
  staging = # Staging with different AWS profile
  dev = # Local dev with mocked services
};
```

Use with:
```bash
nix develop .#staging
```

## Future Enhancements

1. **AWS token support** - Similar to GitHub, use AWS session tokens
2. **Claude API keys** - Support API key auth alongside OAuth
3. **Hermetic builds** - Pure evaluation mode for CI/CD
4. **Custom registries** - Support for private Nix caches
5. **Multi-arch** - ARM64 support for Apple Silicon

## References

- [Nix Flakes Manual](https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html)
- [GitHub Fine-grained Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token)
- [Claude Code Nix Flake](https://github.com/sadjow/claude-code-nix)
