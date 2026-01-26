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