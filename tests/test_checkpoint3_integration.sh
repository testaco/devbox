#!/bin/bash
set -euo pipefail

# =============================================================================
# Checkpoint 3 Integration Test
# =============================================================================
# This test validates the complete devbox workflow using SECRETS (not env vars):
#   1. Initialize devbox (build image, set up credentials)
#   2. Verify GitHub token secret is available
#   3. Create container instance using --github-secret flag (secure file injection)
#   4. Attach to container and wait for nix develop to be ready
#   5. Run test suite inside container (.githooks/pre-commit, git fetch, docker ps, claude)
#   6. Exit cleanly
#
# IMPORTANT: This test uses secure secret injection via Docker volumes.
# The GITHUB_TOKEN env var is only used to SEED the secret store, not passed to containers.
#
# By default, this test runs in BEDROCK mode (--bedrock) which only requires GitHub token.
# Set USE_OAUTH_MODE=1 to test OAuth mode (requires both GitHub and Claude tokens).
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEVBOX_CLI="$PROJECT_ROOT/bin/devbox"

# Test configuration
readonly TEST_CONTAINER_NAME="devbox-test"
readonly TEST_REPO="testaco/devbox"
readonly GITHUB_SECRET_NAME="devbox-github-token"
readonly CLAUDE_SECRET_NAME="devbox-claude-token"
readonly EXPECT_TIMEOUT=600 # 10 minutes max wait for nix develop

# Use Bedrock mode by default (only needs GitHub token)
# Set USE_OAUTH_MODE=1 to test OAuth mode (needs both tokens)
USE_OAUTH_MODE="${USE_OAUTH_MODE:-0}"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# State
CONTAINER_CREATED=false
GITHUB_SECRET_CREATED=false
CLAUDE_SECRET_CREATED=false
GITHUB_SECRET_EXISTS=false
CLAUDE_SECRET_EXISTS=false

# Logging functions
log_info() {
	echo -e "${BLUE}INFO:${NC} $*"
}

log_success() {
	echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
	echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
	echo -e "${RED}✗${NC} $*" >&2
}

log_step() {
	echo ""
	echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo -e "${BLUE}  $*${NC}"
	echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo ""
}

# Cleanup function
cleanup() {
	log_step "Cleanup"

	if [[ "$CONTAINER_CREATED" == true ]]; then
		log_info "Removing test container..."
		"$DEVBOX_CLI" rm -f "$TEST_CONTAINER_NAME" 2>/dev/null || true
	fi

	if [[ "$GITHUB_SECRET_CREATED" == true ]]; then
		log_info "Removing GitHub test secret..."
		"$DEVBOX_CLI" secrets remove "$GITHUB_SECRET_NAME" --force 2>/dev/null || true
	fi

	if [[ "$CLAUDE_SECRET_CREATED" == true ]]; then
		log_info "Removing Claude test secret..."
		"$DEVBOX_CLI" secrets remove "$CLAUDE_SECRET_NAME" --force 2>/dev/null || true
	fi

	log_success "Cleanup complete"
}

# Set trap for cleanup on exit
trap cleanup EXIT

# Check prerequisites
check_prerequisites() {
	log_step "Checking Prerequisites"

	# Check Docker
	if ! command -v docker >/dev/null 2>&1; then
		log_error "Docker not found"
		exit 1
	fi
	log_success "Docker found"

	# Check Docker daemon
	if ! docker info >/dev/null 2>&1; then
		log_error "Docker daemon not running"
		exit 1
	fi
	log_success "Docker daemon running"

	# Check expect
	if ! command -v expect >/dev/null 2>&1; then
		log_error "expect not found - install with: sudo apt-get install expect"
		exit 1
	fi
	log_success "expect found"

	# Check devbox CLI exists
	if [[ ! -x "$DEVBOX_CLI" ]]; then
		log_error "devbox CLI not found at $DEVBOX_CLI"
		exit 1
	fi
	log_success "devbox CLI found"

	# Check for GitHub token secret
	local secrets_path
	secrets_path=$("$DEVBOX_CLI" secrets path)

	if [[ -f "$secrets_path/$GITHUB_SECRET_NAME" ]]; then
		log_success "GitHub secret '$GITHUB_SECRET_NAME' already exists"
		GITHUB_SECRET_EXISTS=true
	elif [[ -n "${GITHUB_TOKEN:-}" ]]; then
		# GITHUB_TOKEN env var exists - import it as a secret immediately
		log_info "Importing GITHUB_TOKEN as secret '$GITHUB_SECRET_NAME'..."
		"$DEVBOX_CLI" secrets add "$GITHUB_SECRET_NAME" --from-env GITHUB_TOKEN
		GITHUB_SECRET_CREATED=true
		GITHUB_SECRET_EXISTS=true
		log_success "Secret '$GITHUB_SECRET_NAME' created from GITHUB_TOKEN"
	else
		log_error "No GitHub token available"
		echo ""
		echo "Create the secret first:"
		echo "  export GITHUB_TOKEN=\"ghp_xxxxxxxxxxxxx\""
		echo "  devbox secrets add $GITHUB_SECRET_NAME --from-env GITHUB_TOKEN"
		echo ""
		echo "Or run this test with GITHUB_TOKEN set:"
		echo "  GITHUB_TOKEN=\"ghp_xxx\" ./tests/test_checkpoint3_integration.sh"
		echo ""
		exit 1
	fi

	# Check for Claude token secret (only needed for OAuth mode)
	if [[ "$USE_OAUTH_MODE" == "1" ]]; then
		if [[ -f "$secrets_path/$CLAUDE_SECRET_NAME" ]]; then
			log_success "Claude secret '$CLAUDE_SECRET_NAME' already exists"
			CLAUDE_SECRET_EXISTS=true
		elif [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
			log_info "Importing CLAUDE_CODE_OAUTH_TOKEN as secret '$CLAUDE_SECRET_NAME'..."
			"$DEVBOX_CLI" secrets add "$CLAUDE_SECRET_NAME" --from-env CLAUDE_CODE_OAUTH_TOKEN
			CLAUDE_SECRET_CREATED=true
			CLAUDE_SECRET_EXISTS=true
			log_success "Secret '$CLAUDE_SECRET_NAME' created from CLAUDE_CODE_OAUTH_TOKEN"
		else
			log_error "OAuth mode requires Claude token"
			echo ""
			echo "Create the Claude secret first:"
			echo "  claude setup-token"
			echo "  devbox secrets add $CLAUDE_SECRET_NAME --from-env CLAUDE_CODE_OAUTH_TOKEN"
			echo ""
			echo "Or run in Bedrock mode (default):"
			echo "  ./tests/test_checkpoint3_integration.sh"
			echo ""
			exit 1
		fi
	else
		log_info "Running in Bedrock mode (no Claude token needed)"
	fi
}

# Step 1: Initialize devbox (always rebuild image)
step_init() {
	log_step "Step 1: Initialize Devbox (devbox init --force)"

	log_info "Running: bin/devbox init --force"
	log_info "This will rebuild the Docker image even if it exists..."

	# Always force rebuild the image (echo y to confirm overwrite)
	if echo "y" | "$DEVBOX_CLI" init --force 2>&1; then
		log_success "Devbox initialized successfully"
	else
		log_error "Failed to initialize devbox"
		exit 1
	fi
}

# Step 2: Verify secrets are ready
step_verify_secret() {
	log_step "Step 2: Verify Secrets"

	# GitHub secret should already exist at this point (created in check_prerequisites)
	if [[ "$GITHUB_SECRET_EXISTS" != true ]]; then
		log_error "GitHub secret '$GITHUB_SECRET_NAME' not available - this should not happen"
		exit 1
	fi

	log_info "Using secret '$GITHUB_SECRET_NAME' for GitHub authentication"

	if [[ "$USE_OAUTH_MODE" == "1" ]]; then
		if [[ "$CLAUDE_SECRET_EXISTS" != true ]]; then
			log_error "Claude secret '$CLAUDE_SECRET_NAME' not available - this should not happen"
			exit 1
		fi
		log_info "Using secret '$CLAUDE_SECRET_NAME' for Claude authentication"
	else
		log_info "Bedrock mode: Claude authentication via AWS credentials"
	fi

	log_success "Secrets ready (secure file-based injection)"
}

# Step 3: Create container instance
step_create_container() {
	log_step "Step 3: Create Container Instance"

	# Remove any existing test container
	if docker ps -aq --filter "name=^devbox-${TEST_CONTAINER_NAME}$" | grep -q .; then
		log_info "Removing existing test container..."
		"$DEVBOX_CLI" rm -f "$TEST_CONTAINER_NAME" 2>/dev/null || true
		sleep 2
	fi

	# Build the create command based on mode
	local create_cmd="$DEVBOX_CLI create $TEST_CONTAINER_NAME $TEST_REPO"
	create_cmd="$create_cmd --github-secret $GITHUB_SECRET_NAME"
	create_cmd="$create_cmd --enable-docker --sudo nopass"

	if [[ "$USE_OAUTH_MODE" == "1" ]]; then
		create_cmd="$create_cmd --claude-code-secret $CLAUDE_SECRET_NAME"
		log_info "Running: $create_cmd"
	else
		create_cmd="$create_cmd --bedrock"
		log_info "Running: $create_cmd"
	fi

	if eval "$create_cmd" 2>&1; then
		CONTAINER_CREATED=true
		log_success "Container '$TEST_CONTAINER_NAME' created successfully"
	else
		log_error "Failed to create container"
		exit 1
	fi
}

# Step 4 & 5: Attach and run tests using expect
step_attach_and_run_tests() {
	log_step "Step 4 & 5: Attach to Container and Run Tests"

	local container_name="devbox-${TEST_CONTAINER_NAME}"

	log_info "Attaching to container and waiting for nix develop..."
	log_info "This may take several minutes while Nix sets up the environment."
	echo ""

	# Create expect script
	local expect_script
	expect_script=$(mktemp)

	cat >"$expect_script" <<'EXPECT_SCRIPT'
#!/usr/bin/expect -f

set timeout 600
set container_name [lindex $argv 0]

# Disable output buffering
log_user 1

puts ">>> Attaching to container: $container_name"

# Spawn docker attach
spawn docker attach $container_name

# Wait for nix develop to finish - look for the ready message
puts ">>> Waiting for nix develop to complete (looking for 'Ready to develop')..."

expect {
    "Ready to develop" {
        puts ">>> Nix develop environment is ready!"
    }
    timeout {
        puts ">>> Timeout waiting for nix develop to complete"
        exit 1
    }
}

# Give it a moment to settle after the ready message
sleep 2

# Send a newline to get a fresh prompt
send "\r"
expect -re {(\$|#|>)}

# Test 1: Run pre-commit hooks
puts "\n>>> Test 1: Running .githooks/pre-commit"
send "./.githooks/pre-commit\r"
expect {
    -re {(\$|#|>)} {
        puts ">>> Pre-commit completed"
    }
    timeout {
        puts ">>> Pre-commit timed out"
        exit 1
    }
}

# Test 2: Git fetch
puts "\n>>> Test 2: Running git fetch"
send "git fetch\r"
expect {
    -re {(\$|#|>)} {
        puts ">>> Git fetch completed"
    }
    timeout {
        puts ">>> Git fetch timed out"
        exit 1
    }
}

# Test 3: Docker ps
puts "\n>>> Test 3: Running docker ps"
send "docker ps\r"
expect {
    -re {(\$|#|>)} {
        puts ">>> Docker ps completed"
    }
    timeout {
        puts ">>> Docker ps timed out"
        exit 1
    }
}

# Test 4: Claude
puts "\n>>> Test 4: Running claude -p 'hi'"
send "claude -p 'hi'\r"
expect {
    -re {(\$|#|>)} {
        puts ">>> Claude completed"
    }
    timeout {
        puts ">>> Claude timed out"
        exit 1
    }
}

# Exit the container shell cleanly
puts "\n>>> Exiting container shell"
send "exit\r"

expect eof

puts "\n>>> All tests completed successfully"
exit 0
EXPECT_SCRIPT

	chmod +x "$expect_script"

	# Run the expect script
	if "$expect_script" "$container_name"; then
		rm -f "$expect_script"
		log_success "All tests passed inside container"
	else
		local exit_code=$?
		rm -f "$expect_script"
		log_error "Tests failed inside container (exit code: $exit_code)"
		log_info "Container logs:"
		docker logs "$container_name" 2>&1 | tail -50
		exit 1
	fi
}

# Step 6: Verify clean exit
step_verify_exit() {
	log_step "Step 6: Verify Clean Exit"

	local container_name="devbox-${TEST_CONTAINER_NAME}"

	# Check container state
	local status
	status=$(docker inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")

	log_info "Container status after exit: $status"

	if [[ "$status" == "exited" ]]; then
		log_success "Container exited cleanly"
	else
		log_warning "Container still running (status: $status), stopping it..."
		"$DEVBOX_CLI" stop "$TEST_CONTAINER_NAME" 2>&1 || true
		log_success "Container stopped"
	fi
}

# Main execution
main() {
	echo ""
	echo "============================================================================="
	echo "  CHECKPOINT 3 INTEGRATION TEST"
	echo "============================================================================="
	echo ""
	if [[ "$USE_OAUTH_MODE" == "1" ]]; then
		echo "  Mode: OAuth (requires GitHub + Claude tokens)"
	else
		echo "  Mode: Bedrock (requires only GitHub token)"
	fi
	echo ""
	echo "This test validates the complete devbox workflow using SECRETS:"
	echo "  1. Initialize devbox (build image, set up credentials)"
	echo "  2. Verify secrets (secure file-based storage)"
	echo "  3. Create container with --github-secret --enable-docker --sudo nopass"
	echo "  4. Attach to container, wait for nix develop"
	echo "  5. Run test suite (pre-commit, git fetch, docker ps, claude)"
	echo "  6. Exit cleanly"
	echo ""
	echo "To run in OAuth mode: USE_OAUTH_MODE=1 $0"
	echo ""

	check_prerequisites
	step_init
	step_verify_secret
	step_create_container
	step_attach_and_run_tests
	step_verify_exit

	echo ""
	echo "============================================================================="
	echo -e "  ${GREEN}CHECKPOINT 3 INTEGRATION TEST PASSED${NC}"
	echo "============================================================================="
	echo ""
}

main "$@"
