#!/bin/bash
set -euo pipefail

# Test suite for devbox create command
# Tests the container creation functionality including flag parsing,
# port mappings, environment variables, and metadata storage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEVBOX_CLI="$PROJECT_ROOT/bin/devbox"

# Test constants
readonly TEST_CONTAINER_PREFIX="devbox-test-"
readonly TEST_REPO="test/test-repo" # New format: owner/repo
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test state
TESTS_RUN=0
TESTS_PASSED=0
CLEANUP_CONTAINERS=()

# Logging
log_test() {
	echo -e "  ${GREEN}✓${NC} $*"
}

log_fail() {
	echo -e "  ${RED}✗${NC} $*"
}

log_info() {
	echo -e "${GREEN}INFO:${NC} $*"
}

log_warning() {
	echo -e "${YELLOW}WARN:${NC} $*"
}

# Setup GITHUB_TOKEN for tests
setup_github_token() {
	# If GITHUB_TOKEN is already set, use it
	if [[ -n "${GITHUB_TOKEN:-}" ]]; then
		log_info "Using existing GITHUB_TOKEN from environment"
		return 0
	fi

	# For dry-run tests, we need a token (even a fake one) to pass validation
	# Real operations won't happen in dry-run mode
	export GITHUB_TOKEN="github_pat_test_token_for_dry_run_only"
	log_warning "No GITHUB_TOKEN found, using test token for dry-run tests only"
}

# Cleanup function
cleanup() {
	log_info "Cleaning up test containers..."
	# Clean up tracked containers
	for container in "${CLEANUP_CONTAINERS[@]}"; do
		docker rm -f "$container" >/dev/null 2>&1 || true
	done
	# Also clean up any leftover devbox-test- containers
	docker ps -aq --filter "name=devbox-test-" | xargs -r docker rm -f >/dev/null 2>&1 || true
}

# Initial cleanup function to remove any leftover containers from previous runs
initial_cleanup() {
	log_info "Cleaning up any leftover test containers from previous runs..."
	docker ps -aq --filter "name=devbox-test-" | xargs -r docker rm -f >/dev/null 2>&1 || true
}

# Set up trap for cleanup
trap cleanup EXIT

# Helper function to track created containers for cleanup
track_container() {
	local name="$1"
	local container_id
	container_id=$(docker ps -aq --filter "name=devbox-test-${name}" | head -1)
	if [[ -n "$container_id" ]]; then
		CLEANUP_CONTAINERS+=("$container_id")
	fi
}

# Test functions
test_create_help() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	if output=$("$DEVBOX_CLI" create --help 2>&1); then
		if [[ "$output" == *"Create and start a new container instance"* ]] &&
			[[ "$output" == *"--port"* ]] &&
			[[ "$output" == *"--github-secret"* ]] &&
			[[ "$output" == *"--claude-code-secret"* ]] &&
			[[ "$output" == *"--bedrock"* ]] &&
			[[ "$output" == *"--aws-profile"* ]]; then
			log_test "create --help shows correct help text with options"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create --help missing expected content"
			echo "Output was: $output"
		fi
	else
		log_fail "create --help failed to run"
	fi
}

test_create_missing_args() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	# Test with no arguments
	output=$("$DEVBOX_CLI" create 2>&1) || exit_code=$?
	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"Container name required"* ]]; then
		log_test "create with no args shows appropriate error"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "create should require container name"
		echo "Output was: $output"
		echo "Exit code was: ${exit_code:-0}"
	fi
}

test_create_missing_repo() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	# Test with name but no repo
	output=$("$DEVBOX_CLI" create test-container 2>&1) || exit_code=$?
	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"Repository required"* ]]; then
		log_test "create with name but no repo shows appropriate error"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "create should require repository (format: owner/repo)"
		echo "Output was: $output"
		echo "Exit code was: ${exit_code:-0}"
	fi
}

test_create_invalid_flag() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	output=$("$DEVBOX_CLI" create test-container "$TEST_REPO" --invalid-flag 2>&1) || exit_code=$?

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"Unknown option"* ]]; then
		log_test "create rejects invalid flags with proper error"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "create should reject invalid flags"
		echo "Output was: $output"
		echo "Exit code was: ${exit_code:-0}"
	fi
}

test_create_basic_container() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_oauth_secrets

	if output=$("$DEVBOX_CLI" create test-basic "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--dry-run 2>&1); then
		if [[ "$output" == *"Would create container"* ]] &&
			[[ "$output" == *"test-basic"* ]] &&
			[[ "$output" == *"$TEST_REPO"* ]]; then
			log_test "create basic container shows correct dry-run output"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create basic container missing expected dry-run content"
			echo "Output was: $output"
		fi
	else
		log_fail "create basic container failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_with_ports() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_oauth_secrets

	if output=$("$DEVBOX_CLI" create test-ports "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--port 3000:3000 --port 8080:80 --dry-run 2>&1); then
		if [[ "$output" == *"3000:3000"* ]] &&
			[[ "$output" == *"8080:80"* ]]; then
			log_test "create with multiple ports shows correct port mappings"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create with ports missing expected port information"
			echo "Output was: $output"
		fi
	else
		log_fail "create with ports failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_bedrock_mode() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_bedrock_secrets

	if output=$("$DEVBOX_CLI" create test-bedrock "$TEST_REPO" \
		--github-secret github-token \
		--bedrock --aws-profile prod --dry-run 2>&1); then
		if [[ "$output" == *"bedrock"* ]] &&
			[[ "$output" == *"AWS Profile: prod"* ]] &&
			[[ "$output" == *"CLAUDE_CODE_USE_BEDROCK=1"* ]]; then
			log_test "create bedrock mode shows correct configuration"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create bedrock mode missing expected configuration"
			echo "Output was: $output"
		fi
	else
		log_fail "create bedrock mode failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_no_docker_by_default() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_oauth_secrets

	# Docker-in-Docker should NOT be enabled by default for security
	# This reduces the attack surface for containers that don't need Docker
	if output=$("$DEVBOX_CLI" create test-no-docker "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--dry-run 2>&1); then
		if [[ "$output" != *"--privileged"* ]] &&
			[[ "$output" != *"DEVBOX_DOCKER_IN_DOCKER"* ]] &&
			[[ "$output" != *"--cap-add"* ]] &&
			[[ "$output" == *"Docker-in-Docker: disabled"* ]]; then
			log_test "create does NOT enable Docker by default (security)"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create should NOT enable Docker by default"
			echo "Output was: $output"
		fi
	else
		log_fail "create failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_enable_docker_flag() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_oauth_secrets

	# --enable-docker should add Docker capabilities (not --privileged)
	if output=$("$DEVBOX_CLI" create test-with-docker "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--enable-docker --dry-run 2>&1); then
		if [[ "$output" == *"--cap-add=SYS_ADMIN"* ]] &&
			[[ "$output" == *"--cap-add=NET_ADMIN"* ]] &&
			[[ "$output" == *"--cap-add=MKNOD"* ]] &&
			[[ "$output" == *"DEVBOX_DOCKER_IN_DOCKER=true"* ]] &&
			[[ "$output" == *"Docker-in-Docker: enabled"* ]]; then
			log_test "create --enable-docker adds correct capabilities"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create --enable-docker missing required capabilities"
			echo "Output was: $output"
		fi
	else
		log_fail "create --enable-docker failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_no_privileged_flag() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_oauth_secrets

	# Even with --enable-docker, should NOT use --privileged (too broad)
	if output=$("$DEVBOX_CLI" create test-no-priv "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--enable-docker --dry-run 2>&1); then
		if [[ "$output" != *"--privileged"* ]]; then
			log_test "create --enable-docker does NOT use --privileged (uses minimal capabilities)"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "SECURITY: --enable-docker should use minimal capabilities, not --privileged"
			echo "Output was: $output"
		fi
	else
		log_fail "create --enable-docker failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_no_host_socket_mount() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_oauth_secrets

	# Verify host Docker socket is NOT mounted (security vulnerability)
	if output=$("$DEVBOX_CLI" create test-no-socket "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--dry-run 2>&1); then
		if [[ "$output" != *"/var/run/docker.sock:/var/run/docker.sock"* ]] &&
			[[ "$output" != *"docker.sock:/var/run/docker.sock"* ]]; then
			log_test "create does NOT mount host Docker socket (security)"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "SECURITY ISSUE: create should not mount host Docker socket"
			echo "This allows container escape: docker run -v /:/host ubuntu cat /host/etc/passwd"
			echo "Output was: $output"
		fi
	else
		log_fail "create failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_no_sudo_by_default() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_oauth_secrets

	# Sudo should NOT be enabled by default
	if output=$("$DEVBOX_CLI" create test-no-sudo "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--dry-run 2>&1); then
		if [[ "$output" != *"DEVBOX_SUDO_MODE"* ]] &&
			[[ "$output" == *"Sudo: disabled"* ]]; then
			log_test "create does NOT enable sudo by default (security)"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create should NOT enable sudo by default"
			echo "Output was: $output"
		fi
	else
		log_fail "create failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_sudo_nopass() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_oauth_secrets

	# --sudo nopass should enable passwordless sudo
	if output=$("$DEVBOX_CLI" create test-sudo-nopass "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--sudo nopass --dry-run 2>&1); then
		if [[ "$output" == *"DEVBOX_SUDO_MODE=nopass"* ]] &&
			[[ "$output" == *"Sudo mode: nopass"* ]]; then
			log_test "create --sudo nopass enables passwordless sudo"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create --sudo nopass missing sudo configuration"
			echo "Output was: $output"
		fi
	else
		log_fail "create --sudo nopass failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_sudo_invalid_mode() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	# --sudo with invalid mode should fail
	set +e
	output=$("$DEVBOX_CLI" create test-sudo-invalid "$TEST_REPO" --sudo invalid 2>&1)
	exit_code=$?
	set -e

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"Invalid sudo mode"* ]]; then
		log_test "create --sudo rejects invalid mode"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "create --sudo should reject invalid mode"
		echo "Exit code was: $exit_code"
		echo "Output was: $output"
	fi
}

test_create_sudo_missing_argument() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	# --sudo without argument should fail
	set +e
	output=$("$DEVBOX_CLI" create test-sudo-noarg "$TEST_REPO" --sudo 2>&1)
	exit_code=$?
	set -e

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"requires an argument"* ]]; then
		log_test "create --sudo requires mode argument"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "create --sudo should require mode argument"
		echo "Exit code was: $exit_code"
		echo "Output was: $output"
	fi
}

test_create_help_shows_security_flags() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	if output=$("$DEVBOX_CLI" create --help 2>&1); then
		if [[ "$output" == *"--enable-docker"* ]] &&
			[[ "$output" == *"--sudo"* ]]; then
			log_test "create --help documents security flags"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create --help should document --enable-docker and --sudo flags"
			echo "Output was: $output"
		fi
	else
		log_fail "create --help failed"
	fi
}

test_entrypoint_no_tcp_socket() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local entrypoint_path="${SCRIPT_DIR}/../docker/entrypoint.sh"

	# Verify entrypoint does NOT expose Docker on TCP socket (security vulnerability)
	if [[ -f "$entrypoint_path" ]]; then
		if grep -q "tcp://0.0.0.0:2375" "$entrypoint_path"; then
			log_fail "SECURITY: entrypoint.sh should NOT expose Docker on TCP socket"
			echo "Found TCP socket exposure in entrypoint.sh"
		else
			log_test "entrypoint.sh does NOT expose Docker TCP socket (security)"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		fi
	else
		log_fail "Could not find entrypoint.sh"
	fi
}

test_create_name_already_exists() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	setup_oauth_secrets

	# First create a container with alpine to avoid entrypoint issues
	local container_id
	container_id=$(docker run -d --name devbox-test-existing alpine sleep 3600)
	CLEANUP_CONTAINERS+=("$container_id")

	# Try to create another container with the same name (using dry-run to avoid token issues)
	output=$("$DEVBOX_CLI" create existing "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--dry-run 2>&1) || exit_code=$?

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"already exists"* ]]; then
		log_test "create rejects duplicate container names"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "create should reject duplicate container names"
		echo "Output was: $output"
		echo "Exit code was: ${exit_code:-0}"
	fi

	cleanup_test_secrets
}

test_create_complex_command() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_bedrock_secrets

	if output=$("$DEVBOX_CLI" create test-complex "$TEST_REPO" \
		--github-secret github-token \
		--port 3000:3000 \
		--port 8080:80 \
		--port 9000:9000 \
		--bedrock \
		--aws-profile staging \
		--dry-run 2>&1); then
		if [[ "$output" == *"test-complex"* ]] &&
			[[ "$output" == *"3000:3000"* ]] &&
			[[ "$output" == *"8080:80"* ]] &&
			[[ "$output" == *"9000:9000"* ]] &&
			[[ "$output" == *"bedrock"* ]] &&
			[[ "$output" == *"AWS Profile: staging"* ]]; then
			log_test "create with complex flags shows all configurations"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create with complex flags missing expected information"
			echo "Output was: $output"
		fi
	else
		log_fail "create with complex flags failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

# ============================================================================
# Secure Secret Injection Tests
# ============================================================================

# Setup temporary secrets directory for testing
setup_test_secrets() {
	TEST_SECRETS_DIR=$(mktemp -d)
	export DEVBOX_SECRETS_DIR="$TEST_SECRETS_DIR"
	mkdir -p "$TEST_SECRETS_DIR"
	chmod 700 "$TEST_SECRETS_DIR"
}

# Setup both GitHub and Claude secrets for OAuth mode tests
setup_oauth_secrets() {
	setup_test_secrets
	echo "test_github_token_12345" >"$TEST_SECRETS_DIR/github-token"
	echo "test_claude_oauth_token" >"$TEST_SECRETS_DIR/claude-oauth-token"
	chmod 600 "$TEST_SECRETS_DIR/github-token"
	chmod 600 "$TEST_SECRETS_DIR/claude-oauth-token"
}

# Setup only GitHub secret for Bedrock mode tests
setup_bedrock_secrets() {
	setup_test_secrets
	echo "test_github_token_12345" >"$TEST_SECRETS_DIR/github-token"
	chmod 600 "$TEST_SECRETS_DIR/github-token"
}

# Cleanup test secrets
cleanup_test_secrets() {
	if [[ -n "${TEST_SECRETS_DIR:-}" ]] && [[ -d "$TEST_SECRETS_DIR" ]]; then
		rm -rf "$TEST_SECRETS_DIR"
	fi
}

test_create_with_github_secret() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_oauth_secrets

	if output=$("$DEVBOX_CLI" create test-secret "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--dry-run 2>&1); then
		if [[ "$output" == *"Would create container"* ]] &&
			[[ "$output" == *"Secrets (mounted to /run/secrets)"* ]] &&
			[[ "$output" == *"github_token"* ]]; then
			log_test "create --github-secret flag shows secret in dry-run"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create --github-secret flag missing expected content"
			echo "Output was: $output"
		fi
	else
		log_fail "create --github-secret flag failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_secrets_not_in_env_vars() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_oauth_secrets

	if output=$("$DEVBOX_CLI" create test-secret-secure "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--dry-run 2>&1); then
		# The docker command should NOT contain GITHUB_TOKEN as env var
		# It should use volume mount to /run/secrets instead
		# Check that there's no "-e GITHUB_TOKEN=" pattern (even masked)
		if [[ "$output" == *"-e GITHUB_TOKEN="* ]]; then
			log_fail "Secret should NOT be passed via -e GITHUB_TOKEN environment variable"
			echo "SECURITY ISSUE: Secret passed as environment variable (visible in docker inspect)"
			echo "Output was: $output"
		elif [[ "$output" == *"/run/secrets"* ]]; then
			log_test "create uses secure file mount instead of environment variable"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "Expected /run/secrets volume mount for secure secret handling"
			echo "Output was: $output"
		fi
	else
		log_fail "create failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_both_secrets_shown() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_oauth_secrets

	if output=$("$DEVBOX_CLI" create test-both-secrets "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--dry-run 2>&1); then
		# Should mention both secrets
		if [[ "$output" == *"github_token"* ]] &&
			[[ "$output" == *"claude_code_token"* ]]; then
			log_test "create shows both github and claude secrets"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create missing some secret references"
			echo "Output was: $output"
		fi
	else
		log_fail "create with both secrets failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_missing_claude_secret_oauth_mode() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	setup_bedrock_secrets # Only sets up github-token, not claude-oauth-token

	set +e
	output=$("$DEVBOX_CLI" create test-missing-claude "$TEST_REPO" \
		--github-secret github-token \
		--dry-run 2>&1)
	exit_code=$?
	set -e

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"Claude Code secret is required"* ]]; then
		log_test "create requires --claude-code-secret in OAuth mode"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "create should require Claude secret in OAuth mode"
		echo "Output was: $output"
		echo "Exit code was: $exit_code"
	fi

	cleanup_test_secrets
}

test_create_bedrock_no_claude_secret() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_bedrock_secrets # Only github-token

	# Bedrock mode should NOT require claude-code-secret
	if output=$("$DEVBOX_CLI" create test-bedrock-only "$TEST_REPO" \
		--github-secret github-token \
		--bedrock \
		--dry-run 2>&1); then
		if [[ "$output" == *"Would create container"* ]] &&
			[[ "$output" == *"Mode: bedrock"* ]] &&
			[[ "$output" != *"claude_code_token"* ]]; then
			log_test "create bedrock mode works without --claude-code-secret"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create bedrock mode unexpected output"
			echo "Output was: $output"
		fi
	else
		log_fail "create bedrock mode failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_github_secret_not_found() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	# Setup empty test secrets directory
	setup_test_secrets

	set +e
	output=$("$DEVBOX_CLI" create test-nosecret "$TEST_REPO" \
		--github-secret nonexistent-secret \
		--claude-code-secret claude-oauth-token \
		--dry-run 2>&1)
	exit_code=$?
	set -e

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"not found"* ]]; then
		log_test "create --github-secret with nonexistent secret shows appropriate error"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "create --github-secret should fail when secret doesn't exist"
		echo "Output was: $output"
		echo "Exit code was: $exit_code"
	fi

	cleanup_test_secrets
}

test_create_missing_github_secret() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	set +e
	output=$("$DEVBOX_CLI" create test-no-github "$TEST_REPO" --dry-run 2>&1)
	exit_code=$?
	set -e

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"GitHub secret is required"* ]]; then
		log_test "create requires --github-secret flag"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "create should require --github-secret flag"
		echo "Output was: $output"
		echo "Exit code was: $exit_code"
	fi
}

test_create_secret_mount_path() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	setup_oauth_secrets

	if output=$("$DEVBOX_CLI" create test-mount "$TEST_REPO" \
		--github-secret github-token \
		--claude-code-secret claude-oauth-token \
		--dry-run 2>&1); then
		# Docker command should include volume mount for secrets
		if [[ "$output" == *"/run/secrets"* ]]; then
			log_test "create mounts secrets to /run/secrets"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create should mount secrets to /run/secrets"
			echo "Output was: $output"
		fi
	else
		log_fail "create failed in dry-run mode"
		echo "Output was: $output"
	fi

	cleanup_test_secrets
}

test_create_help_shows_secret_flags() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	if output=$("$DEVBOX_CLI" create --help 2>&1); then
		# Help text should show new secret flags
		if [[ "$output" == *"--github-secret"* ]] &&
			[[ "$output" == *"--claude-code-secret"* ]]; then
			log_test "create --help documents --github-secret and --claude-code-secret"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create --help should document secret flags"
			echo "Output was: $output"
		fi
	else
		log_fail "create --help failed"
	fi
}

# Main test execution
main() {
	echo "Running devbox create command tests..."

	# Check prerequisites
	if ! command -v docker >/dev/null 2>&1; then
		echo "Docker not found, skipping tests"
		exit 1
	fi

	if ! docker info >/dev/null 2>&1; then
		echo "Docker daemon not running, skipping tests"
		exit 1
	fi

	# Clean up any leftover containers from previous runs
	initial_cleanup

	# Run tests
	test_create_help
	test_create_missing_args
	test_create_missing_repo
	test_create_invalid_flag
	test_create_basic_container
	test_create_with_ports
	test_create_bedrock_mode

	# Security tests - Docker isolation
	test_create_no_docker_by_default
	test_create_enable_docker_flag
	test_create_no_privileged_flag
	test_create_no_host_socket_mount
	test_entrypoint_no_tcp_socket

	# Security tests - Sudo configuration
	test_create_no_sudo_by_default
	test_create_sudo_nopass
	test_create_sudo_invalid_mode
	test_create_sudo_missing_argument
	test_create_help_shows_security_flags

	test_create_name_already_exists
	test_create_complex_command

	# Secure secret injection tests (new flag format)
	test_create_with_github_secret
	test_create_secrets_not_in_env_vars
	test_create_both_secrets_shown
	test_create_missing_claude_secret_oauth_mode
	test_create_bedrock_no_claude_secret
	test_create_github_secret_not_found
	test_create_missing_github_secret
	test_create_secret_mount_path
	test_create_help_shows_secret_flags

	# Results
	echo
	echo "Tests run: $TESTS_RUN"
	echo "Tests passed: $TESTS_PASSED"

	if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
		echo -e "${GREEN}All tests passed!${NC}"
		exit 0
	else
		echo -e "${RED}Some tests failed!${NC}"
		exit 1
	fi
}

main "$@"
