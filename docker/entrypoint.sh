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
# Step 1b: Read Claude Code OAuth Token (for non-Bedrock mode)
# ============================================================================

# Only needed if not using Bedrock
if [ "$CLAUDE_CODE_USE_BEDROCK" != "1" ]; then
	CLAUDE_CODE_OAUTH_TOKEN=""

	# Try reading from secret file
	if [ -f "/run/secrets/claude_code_token" ]; then
		CLAUDE_CODE_OAUTH_TOKEN=$(cat /run/secrets/claude_code_token)
	fi

	if [ -z "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
		echo ""
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo "✗ ERROR: No Claude Code OAuth token provided"
		echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
		echo ""
		echo "A Claude Code OAuth token is required for non-Bedrock mode."
		echo ""
		echo "To obtain a token:"
		echo "  1. Run 'claude setup-token' on your host machine"
		echo "  2. Store the token as a devbox secret:"
		echo "     devbox secrets add claude-oauth-token --from-env CLAUDE_CODE_OAUTH_TOKEN"
		echo "  3. Recreate container with: --claude-code-secret claude-oauth-token"
		echo ""
		exit 1
	fi

	# Export for Claude Code to use
	export CLAUDE_CODE_OAUTH_TOKEN
	echo "✓ Claude Code OAuth token configured"
else
	echo "ℹ️  Bedrock mode enabled - using AWS credentials for Claude"
fi

# ============================================================================
# Step 2: Set up Docker access (DinD only - host socket is not supported)
# ============================================================================

if [ "$DEVBOX_DOCKER_IN_DOCKER" = "true" ]; then
	echo "🐳 Starting Docker-in-Docker..."

	# Verify sudo is available (required for DinD)
	if ! sudo -n true 2>/dev/null; then
		echo "❌ ERROR: Docker-in-Docker requires sudo access"
		echo "   Container was created with --enable-docker but sudo is not configured."
		echo "   This is likely a configuration error."
		exit 1
	fi

	# Clean up any leftover Docker state
	sudo pkill -f dockerd || true
	sudo pkill -f containerd || true
	sudo rm -f /var/run/docker.sock || true
	sudo rm -f /var/run/docker.pid || true
	sudo rm -rf /var/lib/docker || true
	sudo rm -rf /var/lib/containerd || true
	sleep 3

	# Start Docker daemon
	# Only expose Unix socket - no TCP socket for security
	sudo dockerd --storage-driver=vfs --host=unix:///var/run/docker.sock >/tmp/dockerd.log 2>&1 &

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
else
	echo "ℹ️  Docker not enabled (use --enable-docker flag to enable)"
fi

# ============================================================================
# Step 3: Set up AWS credentials (for Bedrock mode)
# ============================================================================

echo "Setting up credentials..."
mkdir -p ~/.claude ~/.aws

# AWS credentials (used by Bedrock mode or for project AWS SDK usage)
if [ -d "/devbox-credentials/aws" ]; then
	cp /devbox-credentials/aws/* ~/.aws/ 2>/dev/null || true
	echo "✓ AWS credentials copied"
fi

# Copy Claude settings (not credentials - those are via CLAUDE_CODE_OAUTH_TOKEN now)
if [ -f "/devbox-credentials/claude/settings.json" ]; then
	cp /devbox-credentials/claude/settings.json ~/.claude/settings.json
	echo "✓ Claude settings copied"
fi

# ============================================================================
# Step 4: Bootstrap Nix environment
# ============================================================================

echo "Bootstrapping Nix environment..."

# Source Nix profile (try both standard and Determinate Systems paths)
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
	source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
elif [ -f /home/devbox/.nix-profile/etc/profile.d/nix.sh ]; then
	source /home/devbox/.nix-profile/etc/profile.d/nix.sh
fi

# Ensure Nix is in PATH (both possible locations)
export PATH="/nix/var/nix/profiles/default/bin:/home/devbox/.nix-profile/bin:$PATH"
export NIX_CONFIG="experimental-features = nix-command flakes"

# ============================================================================
# Step 5: Install gh via Nix
# ============================================================================

# Install gh via Nix if available, otherwise warn
if command -v nix >/dev/null 2>&1; then
	echo "Installing GitHub CLI via Nix..."
	nix profile install nixpkgs#gh
	echo "✓ GitHub CLI installed"
else
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "⚠️  WARNING: Nix is not available"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""
	echo "The Nix package manager was not found. This likely means"
	echo "the Docker image was built with a Nix installation failure."
	echo ""
	echo "To fix, rebuild the Docker image:"
	echo "  devbox init --force"
	echo ""
	echo "Continuing without Nix - gh and nix develop won't be available."
	echo ""
fi

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

# Check if gh is available
if ! command -v gh >/dev/null 2>&1; then
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "✗ ERROR: GitHub CLI (gh) is not available"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""
	echo "The gh command is required to clone repositories."
	echo "This usually means the Nix installation failed."
	echo ""
	echo "To fix, rebuild the Docker image:"
	echo "  devbox init --force"
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
# Step 7: Enter development environment
# ============================================================================

# Check if Nix is available for the development environment
if ! command -v nix >/dev/null 2>&1; then
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "⚠️  Nix is not available - using basic bash shell"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""
	echo "To fix, rebuild the Docker image:"
	echo "  devbox init --force"
	echo ""
	exec bash
fi

if [ -f "flake.nix" ]; then
	echo "Found flake.nix - entering Nix development environment..."
	exec nix develop
elif [ -f "shell.nix" ]; then
	echo "Found shell.nix - entering Nix development environment..."
	exec nix-shell
else
	echo ""
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo "ℹ️  No Nix configuration found (flake.nix or shell.nix)"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	echo ""
	echo "Using base devbox environment with:"
	echo "  • git, gh (GitHub CLI)"
	echo "  • claude (if configured)"
	echo "  • Standard shell tools"
	echo ""
	echo "To add project-specific tools, create a flake.nix:"
	echo "  nix flake init -t github:system1/devbox?dir=base-flake"
	echo ""
	exec bash
fi
