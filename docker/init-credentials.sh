#!/bin/bash
set -euo pipefail

# Credential initialization script for devbox
# This script runs inside a container to set up the credential volume

echo "=== Devbox Credential Initialization ==="

# Create directory structure (will be owned by current user)
echo "Setting up credential directory structure..."
mkdir -p /devbox-credentials/gh
mkdir -p /devbox-credentials/claude
mkdir -p /devbox-credentials/aws

echo "✓ Directory structure created"

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

# Claude configuration setup
echo "=== Importing Claude Configuration ==="
if [[ -f /host-claude/settings.json ]]; then
    echo "Copying Claude settings.json from host..."
    cp /host-claude/settings.json /devbox-credentials/claude/settings.json
    echo "✓ Claude settings.json imported"
    ls -la /devbox-credentials/claude/settings.json
else
    echo "No Claude settings.json found on host - will be created as needed"
fi

# AWS credentials setup
if [[ "${IMPORT_AWS:-false}" == "true" ]]; then
    echo "=== Importing AWS Credentials ==="
    if [[ -d /host-aws ]]; then
        echo "Copying existing AWS credentials from host..."
        cp /host-aws/* /devbox-credentials/aws/ 2>/dev/null || true
        echo "✓ AWS credentials imported"
        ls -la /devbox-credentials/aws/
    elif [[ -d ~/.aws ]]; then
        echo "Copying existing AWS credentials from ~/.aws..."
        cp ~/.aws/* /devbox-credentials/aws/ 2>/dev/null || true
        echo "✓ AWS credentials imported"
        ls -la /devbox-credentials/aws/
    else
        echo "No existing AWS credentials found"
    fi

    # Handle SSO login for Bedrock mode
    if [[ "${BEDROCK_MODE:-false}" == "true" ]]; then
        echo "=== AWS SSO Authentication ==="

        # Check if we have SSO profiles that need authentication
        if [[ -f /devbox-credentials/aws/config ]]; then
            echo "Checking for AWS SSO profiles..."

            # Look for any SSO configuration
            if grep -q "sso_start_url" /devbox-credentials/aws/config 2>/dev/null; then
                echo "Detected AWS SSO configuration. Bedrock mode requires valid SSO tokens."
                echo ""

                # Find all profiles with SSO configuration
                local current_profile=""
                local sso_profiles=()

                while IFS= read -r line; do
                    if [[ $line =~ ^\[profile\ (.+)\]$ ]]; then
                        current_profile="${BASH_REMATCH[1]}"
                    elif [[ $line =~ ^\[default\]$ ]]; then
                        current_profile="default"
                    elif [[ $line =~ ^sso_start_url && -n "$current_profile" ]]; then
                        sso_profiles+=("$current_profile")
                        current_profile=""
                    fi
                done < /devbox-credentials/aws/config

                if [[ ${#sso_profiles[@]} -gt 0 ]]; then
                    echo "Found SSO profiles: ${sso_profiles[*]}"
                    echo ""

                    # Authenticate each SSO profile
                    for profile in "${sso_profiles[@]}"; do
                        echo "Logging in to AWS SSO profile: $profile"
                        echo "This will display a device code - please follow the instructions..."
                        echo ""

                        if aws sso login --profile "$profile" --use-device-code; then
                            echo "✓ SSO login successful for profile: $profile"
                        else
                            echo "✗ SSO login failed for profile: $profile"
                            echo "You can retry this later with: aws sso login --profile $profile --use-device-code"
                        fi
                        echo ""
                    done
                else
                    echo "Could not parse SSO profiles from config file"
                fi
            else
                echo "No SSO configuration detected - skipping SSO login"
            fi
        else
            echo "No AWS config file found - skipping SSO login"
        fi
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