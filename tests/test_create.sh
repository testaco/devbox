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

	if output=$("$DEVBOX_CLI" create test-basic "$TEST_REPO" --dry-run 2>&1); then
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
	fi
}

test_create_with_ports() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	if output=$("$DEVBOX_CLI" create test-ports "$TEST_REPO" --port 3000:3000 --port 8080:80 --dry-run 2>&1); then
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
	fi
}

test_create_bedrock_mode() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	if output=$("$DEVBOX_CLI" create test-bedrock "$TEST_REPO" --bedrock --aws-profile prod --dry-run 2>&1); then
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
	fi
}

test_create_name_already_exists() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	# First create a container with alpine to avoid entrypoint issues
	local container_id
	container_id=$(docker run -d --name devbox-test-existing alpine sleep 3600)
	CLEANUP_CONTAINERS+=("$container_id")

	# Try to create another container with the same name (using dry-run to avoid token issues)
	output=$("$DEVBOX_CLI" create existing "$TEST_REPO" --dry-run 2>&1) || exit_code=$?

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"already exists"* ]]; then
		log_test "create rejects duplicate container names"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "create should reject duplicate container names"
		echo "Output was: $output"
		echo "Exit code was: ${exit_code:-0}"
	fi
}

test_create_complex_command() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	if output=$("$DEVBOX_CLI" create test-complex "$TEST_REPO" \
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
	fi
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

# Cleanup test secrets
cleanup_test_secrets() {
	if [[ -n "${TEST_SECRETS_DIR:-}" ]] && [[ -d "$TEST_SECRETS_DIR" ]]; then
		rm -rf "$TEST_SECRETS_DIR"
	fi
}

test_create_with_secret_flag() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	# Setup test secrets directory
	setup_test_secrets

	# Create a test secret
	echo "test_github_token_12345" >"$TEST_SECRETS_DIR/github-token"
	chmod 600 "$TEST_SECRETS_DIR/github-token"

	# Unset GITHUB_TOKEN to force using the secret
	local saved_token="${GITHUB_TOKEN:-}"
	unset GITHUB_TOKEN

	if output=$("$DEVBOX_CLI" create test-secret "$TEST_REPO" --secret github-token --dry-run 2>&1); then
		if [[ "$output" == *"Would create container"* ]] &&
			[[ "$output" == *"Secrets (mounted to /run/secrets)"* ]] &&
			[[ "$output" == *"github-token"* ]]; then
			log_test "create --secret flag shows secret in dry-run"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create --secret flag missing expected content"
			echo "Output was: $output"
		fi
	else
		log_fail "create --secret flag failed in dry-run mode"
		echo "Output was: $output"
	fi

	# Restore environment
	if [[ -n "$saved_token" ]]; then
		export GITHUB_TOKEN="$saved_token"
	fi
	cleanup_test_secrets
}

test_create_secret_not_in_env_vars() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	# Setup test secrets directory
	setup_test_secrets

	# Create a test secret with a unique value we can search for
	local secret_value="SUPER_SECRET_TOKEN_SHOULD_NOT_APPEAR"
	echo "$secret_value" >"$TEST_SECRETS_DIR/github-token"
	chmod 600 "$TEST_SECRETS_DIR/github-token"

	# Unset GITHUB_TOKEN to force using the secret
	local saved_token="${GITHUB_TOKEN:-}"
	unset GITHUB_TOKEN

	if output=$("$DEVBOX_CLI" create test-secret-secure "$TEST_REPO" --secret github-token --dry-run 2>&1); then
		# The docker command should NOT contain GITHUB_TOKEN as env var
		# It should use volume mount to /run/secrets instead
		# Check that there's no "-e GITHUB_TOKEN=" pattern (even masked)
		if [[ "$output" == *"-e GITHUB_TOKEN="* ]]; then
			log_fail "Secret should NOT be passed via -e GITHUB_TOKEN environment variable"
			echo "SECURITY ISSUE: Secret passed as environment variable (visible in docker inspect)"
			echo "Output was: $output"
		elif [[ "$output" == *"/run/secrets"* ]]; then
			log_test "create --secret uses secure file mount instead of environment variable"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "Expected /run/secrets volume mount for secure secret handling"
			echo "Output was: $output"
		fi
	else
		log_fail "create --secret failed in dry-run mode"
		echo "Output was: $output"
	fi

	# Restore environment
	if [[ -n "$saved_token" ]]; then
		export GITHUB_TOKEN="$saved_token"
	fi
	cleanup_test_secrets
}

test_create_multiple_secrets() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	# Setup test secrets directory
	setup_test_secrets

	# Create multiple test secrets
	echo "github_token_value" >"$TEST_SECRETS_DIR/github-token"
	echo "npm_token_value" >"$TEST_SECRETS_DIR/npm-token"
	echo "custom_api_key" >"$TEST_SECRETS_DIR/api-key"
	chmod 600 "$TEST_SECRETS_DIR/github-token"
	chmod 600 "$TEST_SECRETS_DIR/npm-token"
	chmod 600 "$TEST_SECRETS_DIR/api-key"

	# Unset GITHUB_TOKEN to force using secrets
	local saved_token="${GITHUB_TOKEN:-}"
	unset GITHUB_TOKEN

	if output=$("$DEVBOX_CLI" create test-multi-secret "$TEST_REPO" \
		--secret github-token \
		--secret npm-token \
		--secret api-key \
		--dry-run 2>&1); then
		# Should mention all secrets
		if [[ "$output" == *"github-token"* ]] &&
			[[ "$output" == *"npm-token"* ]] &&
			[[ "$output" == *"api-key"* ]]; then
			log_test "create with multiple --secret flags shows all secrets"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create with multiple secrets missing some secret references"
			echo "Output was: $output"
		fi
	else
		log_fail "create with multiple secrets failed in dry-run mode"
		echo "Output was: $output"
	fi

	# Restore environment
	if [[ -n "$saved_token" ]]; then
		export GITHUB_TOKEN="$saved_token"
	fi
	cleanup_test_secrets
}

test_create_secret_not_found() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	# Setup empty test secrets directory
	setup_test_secrets

	# Unset GITHUB_TOKEN to force using secrets
	local saved_token="${GITHUB_TOKEN:-}"
	unset GITHUB_TOKEN

	set +e
	output=$("$DEVBOX_CLI" create test-nosecret "$TEST_REPO" --secret nonexistent-secret --dry-run 2>&1)
	exit_code=$?
	set -e

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"not found"* ]]; then
		log_test "create --secret with nonexistent secret shows appropriate error"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "create --secret should fail when secret doesn't exist"
		echo "Output was: $output"
		echo "Exit code was: $exit_code"
	fi

	# Restore environment
	if [[ -n "$saved_token" ]]; then
		export GITHUB_TOKEN="$saved_token"
	fi
	cleanup_test_secrets
}

test_create_secret_mount_path() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	# Setup test secrets directory
	setup_test_secrets

	# Create a test secret
	echo "test_token" >"$TEST_SECRETS_DIR/github-token"
	chmod 600 "$TEST_SECRETS_DIR/github-token"

	# Unset GITHUB_TOKEN to force using secrets
	local saved_token="${GITHUB_TOKEN:-}"
	unset GITHUB_TOKEN

	if output=$("$DEVBOX_CLI" create test-mount "$TEST_REPO" --secret github-token --dry-run 2>&1); then
		# Docker command should include volume mount for secrets
		if [[ "$output" == *"/run/secrets"* ]]; then
			log_test "create --secret mounts secrets to /run/secrets"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create --secret should mount secrets to /run/secrets"
			echo "Output was: $output"
		fi
	else
		log_fail "create --secret failed in dry-run mode"
		echo "Output was: $output"
	fi

	# Restore environment
	if [[ -n "$saved_token" ]]; then
		export GITHUB_TOKEN="$saved_token"
	fi
	cleanup_test_secrets
}

test_create_help_shows_multiple_secrets() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	if output=$("$DEVBOX_CLI" create --help 2>&1); then
		# Help text should indicate --secret is repeatable
		if [[ "$output" == *"--secret"* ]] &&
			[[ "$output" == *"repeatable"* || "$output" == *"multiple"* ]]; then
			log_test "create --help documents multiple --secret support"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "create --help should document that --secret is repeatable"
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

	# Setup GITHUB_TOKEN for tests
	setup_github_token

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
	test_create_name_already_exists
	test_create_complex_command

	# Secure secret injection tests
	test_create_with_secret_flag
	test_create_secret_not_in_env_vars
	test_create_multiple_secrets
	test_create_secret_not_found
	test_create_secret_mount_path
	test_create_help_shows_multiple_secrets

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
