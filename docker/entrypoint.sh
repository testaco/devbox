#!/bin/bash
set -e

REPO_URL="${DEVBOX_REPO_URL}"
REPO_DIR="/workspace"

# Set up Claude configuration directory
echo "Setting up Claude configuration..."
mkdir -p ~/.claude

if [ -f "/devbox-credentials/claude/.credentials.json" ]; then
    cp /devbox-credentials/claude/.credentials.json ~/.claude/.credentials.json
    chmod 600 ~/.claude/.credentials.json
    echo "✓ Claude credentials copied to ~/.claude"
fi

if [ -f "/devbox-credentials/claude/settings.json" ]; then
    cp /devbox-credentials/claude/settings.json ~/.claude/settings.json
    echo "✓ Claude settings.json copied to ~/.claude"
fi

# Clone repository if not already present
if [ ! -d "$REPO_DIR/.git" ]; then
    # Use gh repo clone to leverage GitHub CLI authentication
    gh repo clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

# Set up Nix environment (official single-user installation)
if [ -f /home/devbox/.nix-profile/etc/profile.d/nix.sh ]; then
    source /home/devbox/.nix-profile/etc/profile.d/nix.sh
fi

# Ensure Nix is in PATH
export PATH="/home/devbox/.nix-profile/bin:$PATH"

# Experimental features should be read from ~/.config/nix/nix.conf
# But also set via environment as fallback
export NIX_CONFIG="experimental-features = nix-command flakes"

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