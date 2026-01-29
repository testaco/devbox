#!/bin/bash

# Test suite for devbox stop command
# Tests container stopping functionality with comprehensive scenarios

set -euo pipefail

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVBOX_BIN="${SCRIPT_DIR}/../bin/devbox"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test containers to clean up
declare -a TEST_CONTAINERS

# Logging functions
log_test() { echo -e "${BLUE}TEST:${NC} $*"; }
log_pass() {
	echo -e "${GREEN}✓ PASS:${NC} $*"
	((TESTS_PASSED++))
}
log_fail() {
	echo -e "${RED}✗ FAIL:${NC} $*"
	((TESTS_FAILED++))
}
log_skip() {
	echo -e "${BLUE}⊘ SKIP:${NC} $*"
	((TESTS_SKIPPED++))
}

# Cleanup function
cleanup() {
	echo "Cleaning up test containers..."
	# Temporarily disable unbound variable check for array length check
	set +u
	if [ "${#TEST_CONTAINERS[@]}" -gt 0 ]; then
		for container in "${TEST_CONTAINERS[@]}"; do
			docker rm -f "$container" 2>/dev/null || true
		done
	fi
	set -u
}

# Set up cleanup trap
trap cleanup EXIT

# Helper function to create test container
create_test_container() {
	local name="$1"
	local state="${2:-running}"
	local container_name="devbox-test-${name}"

	# Remove existing container if it exists
	docker rm -f "$container_name" >/dev/null 2>&1 || true

	# Create container
	if [ "$state" = "running" ]; then
		docker run -dit --name "$container_name" \
			--label "devbox.repo=git@github.com:test/repo.git" \
			--label "devbox.mode=oauth" \
			--label "devbox.ports=" \
			alpine:latest sleep 300 >/dev/null
	else
		# Create stopped container by starting and then stopping it
		docker run -dit --name "$container_name" \
			--label "devbox.repo=git@github.com:test/repo.git" \
			--label "devbox.mode=oauth" \
			--label "devbox.ports=" \
			alpine:latest sleep 300 >/dev/null
		docker stop "$container_name" >/dev/null 2>&1
	fi

	TEST_CONTAINERS+=("$container_name")
	echo "$container_name"
}

# Test 1: Help text and flag parsing
test_help() {
	log_test "Testing help text and flag parsing"
	((TESTS_RUN++))

	# Test help flag
	if output=$("$DEVBOX_BIN" stop --help 2>&1); then
		if [[ "$output" == *"Stop a container"* ]] && [[ "$output" == *"USAGE:"* ]] && [[ "$output" == *"ARGUMENTS:"* ]]; then
			log_pass "Help text contains expected content"
		else
			log_fail "Help text missing expected content. Got: $output"
			return 1
		fi
	else
		log_fail "Help flag failed"
		return 1
	fi

	# Test invalid flag
	if output=$("$DEVBOX_BIN" stop --invalid-flag 2>&1); then
		log_fail "Invalid flag should have failed but didn't"
		return 1
	else
		if [[ "$output" == *"Unknown option"* ]]; then
			log_pass "Invalid flag properly rejected"
		else
			log_fail "Invalid flag error message incorrect. Got: $output"
			return 1
		fi
	fi
}

# Test 2: Missing argument handling
test_missing_argument() {
	log_test "Testing missing argument handling"
	((TESTS_RUN++))

	if output=$("$DEVBOX_BIN" stop 2>&1); then
		log_fail "Missing argument should have failed but didn't"
		return 1
	else
		if [[ "$output" == *"Container name or ID is required"* ]]; then
			log_pass "Missing argument properly handled"
		else
			log_fail "Missing argument error message incorrect. Got: $output"
			return 1
		fi
	fi
}

# Test 3: Nonexistent container
test_nonexistent_container() {
	log_test "Testing nonexistent container handling"
	((TESTS_RUN++))

	if output=$("$DEVBOX_BIN" stop nonexistent-container 2>&1); then
		log_fail "Nonexistent container should have failed but didn't"
		return 1
	else
		if [[ "$output" == *"Container 'nonexistent-container' not found"* ]]; then
			log_pass "Nonexistent container properly handled"
		else
			log_fail "Nonexistent container error message incorrect. Got: $output"
			return 1
		fi
	fi
}

# Test 4: Stop running container
test_stop_running_container() {
	log_test "Testing stopping a running container"
	((TESTS_RUN++))

	# Create running test container
	container=$(create_test_container "stop-test")

	# Stop the container
	if output=$("$DEVBOX_BIN" stop stop-test 2>&1); then
		# Verify container is stopped
		if status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null); then
			if [[ "$status" == "exited" ]]; then
				log_pass "Container successfully stopped"
			else
				log_fail "Container not stopped. Status: $status"
				return 1
			fi
		else
			log_fail "Failed to check container status after stop"
			return 1
		fi
	else
		log_fail "Stop command failed. Output: $output"
		return 1
	fi
}

# Test 5: Stop already stopped container
test_stop_stopped_container() {
	log_test "Testing stopping an already stopped container"
	((TESTS_RUN++))

	# Create stopped test container
	container=$(create_test_container "stopped-test" "stopped")

	# Try to stop the already stopped container
	if output=$("$DEVBOX_BIN" stop stopped-test 2>&1); then
		if [[ "$output" == *"already stopped"* ]]; then
			log_pass "Stopping already stopped container handled gracefully"
		else
			log_fail "Unexpected output for stopped container. Got: $output"
			return 1
		fi
	else
		log_fail "Stop command failed on already stopped container. Output: $output"
		return 1
	fi
}

# Test 6: Container ID resolution
test_container_id_resolution() {
	log_test "Testing container ID resolution"
	((TESTS_RUN++))

	# Create test container
	container=$(create_test_container "id-test")
	container_id=$(docker inspect --format '{{.Id}}' "$container")
	short_id="${container_id:0:12}"

	# Stop using short ID
	if output=$("$DEVBOX_BIN" stop "$short_id" 2>&1); then
		# Verify container is stopped
		if status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null); then
			if [[ "$status" == "exited" ]]; then
				log_pass "Container ID resolution and stop successful"
			else
				log_fail "Container not stopped via ID. Status: $status"
				return 1
			fi
		else
			log_fail "Failed to check container status after ID stop"
			return 1
		fi
	else
		log_fail "Stop by container ID failed. Output: $output"
		return 1
	fi
}

# Test 7: Dry run mode
test_dry_run() {
	log_test "Testing dry run mode"
	((TESTS_RUN++))

	# Create test container
	container=$(create_test_container "dry-run-test")

	# Test dry run
	if output=$("$DEVBOX_BIN" stop --dry-run dry-run-test 2>&1); then
		if [[ "$output" == *"Would run:"* ]] && [[ "$output" == *"docker stop"* ]]; then
			# Verify container is still running
			if status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null); then
				if [[ "$status" == "running" ]]; then
					log_pass "Dry run mode working correctly"
				else
					log_fail "Dry run actually stopped container. Status: $status"
					return 1
				fi
			else
				log_fail "Failed to check container status after dry run"
				return 1
			fi
		else
			log_fail "Dry run output incorrect. Got: $output"
			return 1
		fi
	else
		log_fail "Dry run failed. Output: $output"
		return 1
	fi
}

# Test 8: Extra arguments rejection
test_extra_arguments() {
	log_test "Testing extra arguments rejection"
	((TESTS_RUN++))

	if output=$("$DEVBOX_BIN" stop container1 container2 extra 2>&1); then
		log_fail "Extra arguments should have failed but didn't"
		return 1
	else
		if [[ "$output" == *"Too many arguments"* ]] || [[ "$output" == *"takes exactly 1 argument"* ]]; then
			log_pass "Extra arguments properly rejected"
		else
			log_fail "Extra arguments error message incorrect. Got: $output"
			return 1
		fi
	fi
}

# Main test runner
main() {
	echo "Running devbox stop command tests..."
	echo "======================================"

	# Check if Docker is available
	if ! docker info >/dev/null 2>&1; then
		echo "Docker is not available. Skipping tests."
		exit 0
	fi

	# Run tests
	test_help || true
	test_missing_argument || true
	test_nonexistent_container || true
	test_stop_running_container || true
	test_stop_stopped_container || true
	test_container_id_resolution || true
	test_dry_run || true
	test_extra_arguments || true

	# Print summary
	echo
	echo "======================================"
	echo "Test Summary:"
	echo "  Ran: $TESTS_RUN"
	echo "  Passed: $TESTS_PASSED"
	echo "  Failed: $TESTS_FAILED"
	echo "  Skipped: $TESTS_SKIPPED"
	echo "======================================"

	if [ $TESTS_FAILED -gt 0 ]; then
		exit 1
	fi
}

# Run main function
main "$@"
