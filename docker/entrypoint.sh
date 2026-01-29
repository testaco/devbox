#!/bin/bash
set -e

REPO="${DEVBOX_REPO:-}"
REPO_DIR="/workspace"

# ============================================================================
# Step 1: Read GitHub Token
# ============================================================================

GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Try reading from secret file if not in env var
if [ -z "$GITHUB_TOKEN" ] && [ -f "/run/secrets/github_token" ]; then
    GITHUB_TOKEN=$(cat /run/secrets/github_token)
fi

# Exit with helpful error if no token
if [ -z "$GITHUB_TOKEN" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✗ ERROR: No GitHub token provided"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "A GitHub token is required to clone repositories."
    echo ""
    echo "Please provide a token using one of these methods:"
    echo ""
    echo "  1. Environment variable:"
    echo "     docker run -e GITHUB_TOKEN=\"github_pat_xxx\" ..."
    echo ""
    echo "  2. Secret file (more secure):"
    echo "     docker run -v ~/.secrets/token:/run/secrets/github_token:ro ..."
    echo ""
    echo "To create a fine-grained token:"
    echo "  1. Go to: GitHub → Settings → Developer settings → Fine-grained tokens"
    echo "  2. Create token with access to your repository"
    echo "  3. Minimum permissions: Contents: Read"
    echo "  4. For pushing: Contents: Read and Write"
    echo ""
    exit 1
fi

# Export token for gh to use
export GITHUB_TOKEN

# ============================================================================
# Step 2: Set up Docker access (DinD or host socket)
# ============================================================================

if [ "$DEVBOX_DOCKER_IN_DOCKER" = "true" ]; then
    echo "🐳 Starting Docker-in-Docker..."

    # Clean up any leftover Docker state
    sudo pkill -f dockerd || true
    sudo pkill -f containerd || true
    sudo rm -f /var/run/docker.sock || true
    sudo rm -f /var/run/docker.pid || true
    sudo rm -rf /var/lib/docker || true
    sudo rm -rf /var/lib/containerd || true
    sleep 3

    # Start Docker daemon
    sudo dockerd --storage-driver=vfs --host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 >/tmp/dockerd.log 2>&1 &

    # Wait for Docker daemon
    echo "⏳ Waiting for Docker daemon to start..."
    for i in {1..60}; do
        if sudo docker info >/dev/null 2>&1; then
            echo "✅ Docker daemon is ready"
            break
        fi
        sleep 1
        if [ $i -eq 60 ]; then
            echo "❌ Docker daemon failed to start within 60 seconds"
            echo "⚠️  Continuing without Docker-in-Docker functionality"
            break
        fi
    done

elif [ -S "/var/run/docker.sock" ]; then
    echo "🔧 Fixing Docker socket permissions for host access..."
    sudo chmod 666 /var/run/docker.sock
    echo "✅ Docker socket permissions updated"
else
    echo "ℹ️  No Docker access configured"
fi

# ============================================================================
# Step 3: Set up Claude and AWS credentials
# ============================================================================

echo "Setting up credentials..."
mkdir -p ~/.claude ~/.aws

# Claude credentials
if [ -f "/devbox-credentials/claude/.credentials.json" ]; then
    cp /devbox-credentials/claude/.credentials.json ~/.claude/.credentials.json
    chmod 600 ~/.claude/.credentials.json
    echo "✓ Claude credentials copied"
fi

if [ -f "/devbox-credentials/claude/settings.json" ]; then
    cp /devbox-credentials/claude/settings.json ~/.claude/settings.json
    echo "✓ Claude settings copied"
fi

# AWS credentials
if [ -d "/devbox-credentials/aws" ]; then
    cp /devbox-credentials/aws/* ~/.aws/ 2>/dev/null || true
    echo "✓ AWS credentials copied"
fi

# ============================================================================
# Step 4: Bootstrap Nix environment
# ============================================================================

echo "Bootstrapping Nix environment..."

# Source Nix profile
if [ -f /home/devbox/.nix-profile/etc/profile.d/nix.sh ]; then
    source /home/devbox/.nix-profile/etc/profile.d/nix.sh
fi

# Ensure Nix is in PATH
export PATH="/home/devbox/.nix-profile/bin:$PATH"
export NIX_CONFIG="experimental-features = nix-command flakes"

# ============================================================================
# Step 5: Install gh via Nix
# ============================================================================

echo "Installing GitHub CLI via Nix..."
nix profile install nixpkgs#gh
echo "✓ GitHub CLI installed"

# ============================================================================
# Step 6: Validate token and clone repository
# ============================================================================

if [ -z "$REPO" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✗ ERROR: No repository specified"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Please provide a repository via DEVBOX_REPO environment variable:"
    echo "  docker run -e DEVBOX_REPO=\"owner/repo\" ..."
    echo ""
    exit 1
fi

# Clone repository if not already present
if [ ! -d "$REPO_DIR/.git" ]; then
    echo "Cloning repository: $REPO"

    if ! gh repo clone "$REPO" "$REPO_DIR" 2>&1; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✗ ERROR: Failed to clone repository"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Repository: $REPO"
        echo ""
        echo "Possible causes:"
        echo "  • Repository does not exist or URL is incorrect"
        echo "  • Token doesn't have access to this repository"
        echo "  • Token has insufficient permissions (needs Contents: Read)"
        echo "  • Network connectivity issues"
        echo ""
        echo "To fix:"
        echo "  1. Verify the repository name is correct (format: owner/repo)"
        echo "  2. Ensure your token has access to this repository"
        echo "  3. Check token permissions include Contents: Read"
        echo ""
        exit 1
    fi
    echo "✓ Repository cloned successfully"
fi

cd "$REPO_DIR"

# ============================================================================
# Step 7: Verify Nix configuration exists
# ============================================================================

if [ ! -f "flake.nix" ] && [ ! -f "shell.nix" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✗ ERROR: No Nix configuration found"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Repository: $REPO"
    echo "Expected: flake.nix or shell.nix"
    echo ""
    echo "To add a flake.nix, you can use the devbox template:"
    echo "  nix flake init -t github:system1/devbox"
    echo ""
    echo "Or see: https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html"
    echo ""
    exit 1
fi

# ============================================================================
# Step 8: Enter Nix development environment
# ============================================================================

echo "Entering Nix development environment..."

if [ -f "flake.nix" ]; then
    exec nix develop
else
    exec nix-shell
fi