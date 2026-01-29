#!/bin/bash
set -euo pipefail

# Test suite for devbox attach command
# Tests container attachment functionality including name resolution,
# error handling for non-existent containers, and proper Docker interaction

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEVBOX_CLI="$PROJECT_ROOT/bin/devbox"

# Test constants
readonly TEST_CONTAINER_PREFIX="devbox-test-"
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
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
	local container_id="$1"
	if [[ -n "$container_id" ]]; then
		CLEANUP_CONTAINERS+=("$container_id")
	fi
}

# Test functions
test_attach_help() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	if output=$("$DEVBOX_CLI" attach --help 2>&1); then
		if [[ "$output" == *"Attach to a running container's shell"* ]] &&
			[[ "$output" == *"<name|id>"* ]] &&
			[[ "$output" == *"USAGE:"* ]]; then
			log_test "attach --help shows correct help text"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "attach --help missing expected content"
			echo "Output was: $output"
		fi
	else
		log_fail "attach --help failed to run"
	fi
}

test_attach_missing_args() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	# Test with no arguments
	output=$("$DEVBOX_CLI" attach 2>&1) || exit_code=$?
	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"Container name or ID required"* ]]; then
		log_test "attach with no args shows appropriate error"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "attach should require container name or ID"
		echo "Output was: $output"
		echo "Exit code was: ${exit_code:-0}"
	fi
}

test_attach_invalid_flag() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	output=$("$DEVBOX_CLI" attach test-container --invalid-flag 2>&1) || exit_code=$?

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"Unknown option"* ]]; then
		log_test "attach rejects invalid flags with proper error"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "attach should reject invalid flags"
		echo "Output was: $output"
		echo "Exit code was: ${exit_code:-0}"
	fi
}

test_attach_nonexistent_container() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	output=$("$DEVBOX_CLI" attach nonexistent-container 2>&1) || exit_code=$?
	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"Container 'nonexistent-container' not found"* ]]; then
		log_test "attach with nonexistent container shows appropriate error"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "attach should handle nonexistent container gracefully"
		echo "Output was: $output"
		echo "Exit code was: ${exit_code:-0}"
	fi
}

test_attach_stopped_container() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	# Create a stopped container
	local container_id
	container_id=$(docker create --name devbox-test-stopped alpine sleep 3600)
	track_container "$container_id"

	output=$("$DEVBOX_CLI" attach stopped 2>&1) || exit_code=$?
	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"not running"* ]]; then
		log_test "attach to stopped container shows appropriate error"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "attach should require container to be running"
		echo "Output was: $output"
		echo "Exit code was: ${exit_code:-0}"
	fi
}

test_attach_dry_run_mode() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	# Create a running container
	local container_id
	container_id=$(docker run -d --name devbox-test-running alpine sleep 3600)
	track_container "$container_id"

	if output=$("$DEVBOX_CLI" attach running --dry-run 2>&1); then
		if [[ "$output" == *"Would attach to container"* ]] &&
			[[ "$output" == *"running"* ]] &&
			[[ "$output" == *"docker attach"* ]]; then
			log_test "attach dry-run shows correct output"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "attach dry-run missing expected content"
			echo "Output was: $output"
		fi
	else
		log_fail "attach dry-run failed"
	fi
}

test_attach_by_container_id() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output

	# Create a running container
	local container_id short_id
	container_id=$(docker run -d --name devbox-test-byid alpine sleep 3600)
	short_id="${container_id:0:8}"
	track_container "$container_id"

	if output=$("$DEVBOX_CLI" attach "$short_id" --dry-run 2>&1); then
		if [[ "$output" == *"Would attach to container"* ]] &&
			[[ "$output" == *"$short_id"* ]]; then
			log_test "attach by container ID works correctly"
			TESTS_PASSED=$((TESTS_PASSED + 1))
		else
			log_fail "attach by container ID failed"
			echo "Output was: $output"
		fi
	else
		log_fail "attach by container ID failed in dry-run mode"
	fi
}

test_attach_extra_args() {
	TESTS_RUN=$((TESTS_RUN + 1))
	local output exit_code

	output=$("$DEVBOX_CLI" attach test-container extra args 2>&1) || exit_code=$?

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"Unexpected argument"* ]]; then
		log_test "attach rejects extra arguments"
		TESTS_PASSED=$((TESTS_PASSED + 1))
	else
		log_fail "attach should reject extra arguments"
		echo "Output was: $output"
		echo "Exit code was: ${exit_code:-0}"
	fi
}

# Main test execution
main() {
	echo "Running devbox attach command tests..."

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
	test_attach_help
	test_attach_missing_args
	test_attach_invalid_flag
	test_attach_nonexistent_container
	test_attach_stopped_container
	test_attach_dry_run_mode
	test_attach_by_container_id
	test_attach_extra_args

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
