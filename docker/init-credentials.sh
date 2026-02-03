#!/bin/bash
set -euo pipefail

# Credential initialization script for devbox
# This script runs inside a container to set up Claude and AWS credentials
# Note: GitHub auth is now handled via GITHUB_TOKEN (no OAuth needed)

echo "=== Devbox Credential Initialization ==="

# Create directory structure (will be owned by current user)
echo "Setting up credential directory structure..."
mkdir -p /devbox-credentials/claude
mkdir -p /devbox-credentials/aws

echo "✓ Directory structure created"

# Set environment variables for tools
export CLAUDE_CONFIG_DIR=/devbox-credentials/claude
export AWS_CONFIG_FILE=/devbox-credentials/aws/config
export AWS_SHARED_CREDENTIALS_FILE=/devbox-credentials/aws/credentials

# Claude settings import (not credentials - those are now via CLAUDE_CODE_OAUTH_TOKEN)
echo "=== Checking Claude Settings ==="
if [[ -f /devbox-credentials/claude/settings.json ]]; then
	echo "✓ Claude settings already present"
elif [[ -f /host-claude/settings.json ]]; then
	echo "Copying Claude settings.json from host..."
	cp /host-claude/settings.json /devbox-credentials/claude/settings.json 2>/dev/null || {
		echo "Note: Settings will be imported by root process"
	}
fi

# Note: Claude OAuth authentication is no longer performed during init
# Users now provide an OAuth token via 'claude setup-token' stored as a devbox secret
if [[ "${BEDROCK_MODE:-false}" != "true" ]]; then
	echo "=== Claude Code Setup ==="
	echo "Note: Claude authentication is now token-based, not OAuth-during-init."
	echo "To authenticate Claude Code in containers:"
	echo "  1. Run 'claude setup-token' on your host machine"
	echo "  2. Store the token: devbox secrets add claude-oauth-token --from-env CLAUDE_CODE_OAUTH_TOKEN"
	echo "  3. Create containers with: --claude-code-secret claude-oauth-token"
else
	echo "=== Skipping Claude OAuth (Bedrock mode) ==="
	echo "AWS Bedrock mode enabled - Claude authentication will use AWS credentials"
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
				current_profile=""
				sso_profiles=()

				while IFS= read -r line; do
					if [[ $line =~ ^\[profile\ (.+)\]$ ]]; then
						current_profile="${BASH_REMATCH[1]}"
					elif [[ $line =~ ^\[default\]$ ]]; then
						current_profile="default"
					elif [[ $line =~ ^sso_start_url && -n "$current_profile" ]]; then
						sso_profiles+=("$current_profile")
						current_profile=""
					fi
				done </devbox-credentials/aws/config

				if [[ ${#sso_profiles[@]} -gt 0 ]]; then
					echo "Found SSO profiles: ${sso_profiles[*]}"
					echo ""

					# Check if a specific profile was requested
					if [[ -n "${AWS_SSO_PROFILE:-}" ]]; then
						# Authenticate only the specified profile
						if [[ " ${sso_profiles[*]} " =~ " ${AWS_SSO_PROFILE} " ]]; then
							echo "Authenticating specified AWS SSO profile: $AWS_SSO_PROFILE"
							echo "This will display a device code - please follow the instructions..."
							echo ""

							if aws sso login --profile "$AWS_SSO_PROFILE" --use-device-code; then
								echo "✓ SSO login successful for profile: $AWS_SSO_PROFILE"
							else
								echo "✗ SSO login failed for profile: $AWS_SSO_PROFILE"
								echo "You can retry this later with: aws sso login --profile $AWS_SSO_PROFILE --use-device-code"
							fi
						else
							echo "✗ Specified profile '$AWS_SSO_PROFILE' not found in SSO profiles: ${sso_profiles[*]}"
							echo "Available profiles: ${sso_profiles[*]}"
						fi
					else
						# Authenticate all SSO profiles (original behavior)
						echo "Authenticating all SSO profiles..."
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
					fi
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
	echo "Authentication: GitHub token (secret) + AWS credentials"
else
	echo "Mode: Token-based OAuth"
	echo "Authentication: GitHub token (secret) + Claude OAuth token (secret)"
	echo ""
	echo "Next steps for OAuth mode containers:"
	echo "  1. Get Claude token: claude setup-token"
	echo "  2. Store it: devbox secrets add claude-oauth-token --from-env CLAUDE_CODE_OAUTH_TOKEN"
fi
