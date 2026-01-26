#!/bin/bash
set -e

REPO_URL="${DEVBOX_REPO_URL}"
REPO_DIR="/workspace"

# Clone repository if not already present
if [ ! -d "$REPO_DIR/.git" ]; then
    # Use gh repo clone to leverage GitHub CLI authentication
    gh repo clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

# Set up Nix environment (single-user mode)
# Try both profile locations for different installation types
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]; then
    source /nix/var/nix/profiles/default/etc/profile.d/nix.sh
elif [ -f /home/devbox/.nix-profile/etc/profile.d/nix.sh ]; then
    source /home/devbox/.nix-profile/etc/profile.d/nix.sh
fi

# Add both potential Nix paths
export PATH="/nix/var/nix/profiles/default/bin:/home/devbox/.nix-profile/bin:$PATH"

# Ensure experimental features are enabled for this session
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