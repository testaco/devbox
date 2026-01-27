#!/bin/bash
set -e

REPO_URL="${DEVBOX_REPO_URL}"
REPO_DIR="/workspace"

# Fix Docker socket permissions if it exists (for rootless Docker access)
if [ -S "/var/run/docker.sock" ]; then
    echo "Fixing Docker socket permissions..."
    sudo chmod 666 /var/run/docker.sock
fi

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
    echo "Cloning repository: $REPO_URL"
    # Use gh repo clone to leverage GitHub CLI authentication
    if ! gh repo clone "$REPO_URL" "$REPO_DIR" 2>&1; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✗ ERROR: Failed to clone repository"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Repository: $REPO_URL"
        echo ""
        echo "Possible causes:"
        echo "  • Repository does not exist or URL is incorrect"
        echo "  • You don't have access to this repository"
        echo "  • Network connectivity issues"
        echo "  • GitHub authentication issues"
        echo ""
        echo "To fix:"
        echo "  1. Verify the repository URL is correct"
        echo "  2. Ensure you have access to the repository"
        echo "  3. Check your GitHub authentication with: devbox exec <container> gh auth status"
        echo "  4. Try re-running: devbox init"
        echo ""
        exit 1
    fi
    echo "✓ Repository cloned successfully"
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
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✗ ERROR: No Nix configuration found"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Repository: $REPO_URL"
    echo "Expected: flake.nix or shell.nix"
    echo ""
    echo "Devbox requires a Nix configuration to set up the development"
    echo "environment with the correct dependencies."
    echo ""
    echo "To fix this, add either:"
    echo ""
    echo "  1. flake.nix (recommended) - Modern Nix flakes configuration"
    echo "  2. shell.nix (legacy) - Traditional Nix shell configuration"
    echo ""
    echo "Example flake.nix:"
    echo "  {"
    echo "    description = \"Dev environment\";"
    echo "    inputs.nixpkgs.url = \"github:NixOS/nixpkgs/nixos-unstable\";"
    echo "    outputs = { self, nixpkgs }: {"
    echo "      devShells.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {"
    echo "        buildInputs = [ nixpkgs.legacyPackages.x86_64-linux.nodejs ];"
    echo "      };"
    echo "    };"
    echo "  }"
    echo ""
    echo "For more information:"
    echo "  https://nixos.org/manual/nix/stable/command-ref/new-cli/nix3-flake.html"
    echo ""
    exit 1
fi

# Enter Nix shell
echo "Entering Nix development environment..."
if [ -f "flake.nix" ]; then
    if ! nix develop --command bash; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✗ ERROR: Failed to enter Nix development environment"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "The flake.nix file may have syntax errors or invalid configuration."
        echo ""
        echo "To debug:"
        echo "  1. Verify your flake.nix is valid: nix flake check"
        echo "  2. Check for syntax errors in the file"
        echo "  3. Ensure all inputs are accessible"
        echo ""
        exit 1
    fi
else
    if ! nix-shell --command bash; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✗ ERROR: Failed to enter Nix shell environment"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "The shell.nix file may have syntax errors or invalid configuration."
        echo ""
        echo "To debug:"
        echo "  1. Verify your shell.nix is valid"
        echo "  2. Check for syntax errors in the file"
        echo "  3. Ensure all dependencies are accessible"
        echo ""
        exit 1
    fi
fi