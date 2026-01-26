#!/bin/bash
set -euo pipefail

# Credential initialization script for devbox
# This script runs inside a container to set up the credential volume
# It should be run as root initially, then switches to devbox user

echo "=== Devbox Credential Initialization ==="

# Ensure we're running as root for initial setup
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root for initial setup"
    exit 1
fi

# Create directory structure with proper permissions
echo "Setting up credential directory structure..."
mkdir -p /devbox-credentials/gh
mkdir -p /devbox-credentials/claude
mkdir -p /devbox-credentials/aws

# Change ownership to devbox user
chown -R devbox:devbox /devbox-credentials

echo "✓ Directory structure created"

# Switch to devbox user for authentication
exec sudo -u devbox bash << 'EOF'

# Set environment variables for tools to use the credential directories
export GH_CONFIG_DIR=/devbox-credentials/gh
export CLAUDE_CONFIG_DIR=/devbox-credentials/claude
export AWS_CONFIG_FILE=/devbox-credentials/aws/config
export AWS_SHARED_CREDENTIALS_FILE=/devbox-credentials/aws/credentials

echo "=== GitHub CLI Authentication ==="
echo "Please authenticate with GitHub CLI..."
echo "This will open a browser window for OAuth authentication."

# GitHub CLI authentication
gh auth login --web

# Verify GitHub authentication
if gh auth status >/dev/null 2>&1; then
    echo "✓ GitHub CLI authentication successful"
    gh auth status
else
    echo "✗ GitHub CLI authentication failed"
    exit 1
fi

# Claude authentication (only if not in Bedrock mode)
if [[ "${BEDROCK_MODE:-false}" != "true" ]]; then
    echo "=== Claude Code Authentication ==="
    echo "Please authenticate with Claude Code..."
    echo "This will open a browser window for OAuth authentication."

    # Claude Code authentication - just run claude to trigger OAuth flow
    claude --version >/dev/null || {
        echo "Starting Claude Code authentication..."
        # Claude Code will handle the OAuth flow when first run
        claude || {
            echo "✗ Claude Code authentication failed"
            exit 1
        }
    }

    if [[ -f /devbox-credentials/claude/.credentials.json ]]; then
        echo "✓ Claude Code authentication successful"
    else
        echo "✗ Claude Code authentication failed - no credentials file found"
        exit 1
    fi
else
    echo "=== Skipping Claude OAuth (Bedrock mode) ==="
    echo "AWS Bedrock mode enabled - Claude authentication will use AWS credentials"
fi

# AWS credentials setup
if [[ "${IMPORT_AWS:-false}" == "true" ]]; then
    echo "=== Importing AWS Credentials ==="
    if [[ -d ~/.aws ]]; then
        echo "Copying existing AWS credentials from host..."
        cp ~/.aws/* /devbox-credentials/aws/ 2>/dev/null || true
        echo "✓ AWS credentials imported"
        ls -la /devbox-credentials/aws/
    else
        echo "No existing AWS credentials found in ~/.aws"
    fi
else
    echo "=== Manual AWS Setup ==="
    echo "To configure AWS credentials manually, you can:"
    echo "1. Use 'aws configure' inside a devbox container"
    echo "2. Or copy your ~/.aws/ files to the credential volume"
fi

echo "=== Initialization Summary ==="
echo "Credential directory contents:"
find /devbox-credentials -type f -exec ls -la {} \;

echo ""
echo "✓ Devbox initialization completed successfully!"
echo ""
if [[ "${BEDROCK_MODE:-false}" == "true" ]]; then
    echo "Mode: AWS Bedrock"
    echo "Authentication: GitHub CLI + AWS credentials"
else
    echo "Mode: Claude OAuth"
    echo "Authentication: GitHub CLI + Claude OAuth"
fi

EOF