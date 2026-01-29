#!/bin/bash

# Test suite for devbox logs command
# Tests log viewing functionality with comprehensive scenarios

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
	if [[ -n "${TEST_CONTAINERS:-}" ]] && [[ ${#TEST_CONTAINERS[@]} -gt 0 ]]; then
		for container in "${TEST_CONTAINERS[@]}"; do
			docker rm -f "$container" 2>/dev/null || true
		done
	fi
}

# Set up cleanup trap
trap cleanup EXIT

# Helper function to create test container with logging
create_test_container() {
	local name="$1"
	local state="${2:-running}"
	local container_name="devbox-test-${name}"

	# Create container that generates logs
	if [ "$state" = "running" ]; then
		docker run -dit --name "$container_name" \
			--label "devbox.repo=git@github.com:test/repo.git" \
			--label "devbox.mode=oauth" \
			--label "devbox.ports=" \
			alpine:latest sh -c 'echo "Container started"; echo "Line 1"; echo "Line 2"; sleep 300' >/dev/null
	else
		# Create stopped container by starting and then stopping it
		docker run -dit --name "$container_name" \
			--label "devbox.repo=git@github.com:test/repo.git" \
			--label "devbox.mode=oauth" \
			--label "devbox.ports=" \
			alpine:latest sh -c 'echo "Container started"; sleep 300' >/dev/null
		sleep 1 # Give it time to log
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
	if output=$("$DEVBOX_BIN" logs --help 2>&1); then
		if [[ "$output" == *"View container logs"* ]] && [[ "$output" == *"USAGE:"* ]] && [[ "$output" == *"ARGUMENTS:"* ]]; then
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
	if output=$("$DEVBOX_BIN" logs --invalid-flag 2>&1); then
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

# Test 2: Missing container name
test_missing_name() {
	log_test "Testing missing container name"
	((TESTS_RUN++))

	if output=$("$DEVBOX_BIN" logs 2>&1); then
		log_fail "Command should fail without container name"
		return 1
	else
		if [[ "$output" == *"Container name or ID is required"* ]]; then
			log_pass "Missing container name properly rejected"
		else
			log_fail "Error message incorrect. Got: $output"
			return 1
		fi
	fi
}

# Test 3: Container not found
test_not_found() {
	log_test "Testing container not found"
	((TESTS_RUN++))

	if output=$("$DEVBOX_BIN" logs nonexistent 2>&1); then
		log_fail "Command should fail for nonexistent container"
		return 1
	else
		if [[ "$output" == *"not found"* ]]; then
			log_pass "Nonexistent container properly rejected"
		else
			log_fail "Error message incorrect. Got: $output"
			return 1
		fi
	fi
}

# Test 4: Basic log viewing
test_basic_logs() {
	log_test "Testing basic log viewing"
	((TESTS_RUN++))

	# Create test container
	local container_name
	container_name=$(create_test_container "logtest")

	# Give container time to generate logs
	sleep 1

	# View logs
	if output=$("$DEVBOX_BIN" logs logtest 2>&1); then
		if [[ "$output" == *"Container started"* ]]; then
			log_pass "Basic log viewing works"
		else
			log_fail "Expected log content not found. Got: $output"
			return 1
		fi
	else
		log_fail "Failed to view logs. Output: $output"
		return 1
	fi
}

# Test 5: Logs by container ID
test_logs_by_id() {
	log_test "Testing logs by container ID"
	((TESTS_RUN++))

	# Create test container
	local container_name
	container_name=$(create_test_container "idtest")

	# Get container ID
	local container_id
	container_id=$(docker ps -q --filter "name=^${container_name}$")
	local short_id="${container_id:0:8}"

	# Give container time to generate logs
	sleep 1

	# View logs by ID
	if output=$("$DEVBOX_BIN" logs "$short_id" 2>&1); then
		if [[ "$output" == *"Container started"* ]]; then
			log_pass "Log viewing by ID works"
		else
			log_fail "Expected log content not found. Got: $output"
			return 1
		fi
	else
		log_fail "Failed to view logs by ID. Output: $output"
		return 1
	fi
}

# Test 6: Logs from stopped container
test_stopped_container() {
	log_test "Testing logs from stopped container"
	((TESTS_RUN++))

	# Create stopped test container
	local container_name
	container_name=$(create_test_container "stoppedtest" "stopped")

	# View logs from stopped container
	if output=$("$DEVBOX_BIN" logs stoppedtest 2>&1); then
		if [[ "$output" == *"Container started"* ]]; then
			log_pass "Log viewing from stopped container works"
		else
			log_fail "Expected log content not found. Got: $output"
			return 1
		fi
	else
		log_fail "Failed to view logs from stopped container. Output: $output"
		return 1
	fi
}

# Test 7: Dry run mode
test_dry_run() {
	log_test "Testing dry run mode"
	((TESTS_RUN++))

	# Create test container
	local container_name
	container_name=$(create_test_container "dryruntest")

	# Test dry run
	if output=$("$DEVBOX_BIN" logs dryruntest --dry-run 2>&1); then
		if [[ "$output" == *"Would run:"* ]] && [[ "$output" == *"docker logs"* ]]; then
			log_pass "Dry run mode works"
		else
			log_fail "Dry run output incorrect. Got: $output"
			return 1
		fi
	else
		log_fail "Dry run failed"
		return 1
	fi
}

# Test 8: Follow flag parsing (-f and --follow)
test_follow_flag() {
	log_test "Testing follow flag parsing"
	((TESTS_RUN++))

	# Create test container
	local container_name
	container_name=$(create_test_container "followtest")

	# Test -f flag in dry run (to avoid hanging)
	if output=$("$DEVBOX_BIN" logs followtest -f --dry-run 2>&1); then
		if [[ "$output" == *"docker logs"* ]] && [[ "$output" == *"-f"* ]]; then
			log_pass "-f flag properly parsed"
		else
			log_fail "-f flag not properly parsed. Got: $output"
			return 1
		fi
	else
		log_fail "-f flag parsing failed"
		return 1
	fi

	# Test --follow flag in dry run
	if output=$("$DEVBOX_BIN" logs followtest --follow --dry-run 2>&1); then
		if [[ "$output" == *"docker logs"* ]] && [[ "$output" == *"-f"* ]]; then
			log_pass "--follow flag properly parsed"
		else
			log_fail "--follow flag not properly parsed. Got: $output"
			return 1
		fi
	else
		log_fail "--follow flag parsing failed"
		return 1
	fi
}

# Test 9: Multiple line limit options
test_tail_option() {
	log_test "Testing --tail option"
	((TESTS_RUN++))

	# Create test container
	local container_name
	container_name=$(create_test_container "tailtest")

	# Give container time to generate logs
	sleep 1

	# Test --tail flag in dry run
	if output=$("$DEVBOX_BIN" logs tailtest --tail 10 --dry-run 2>&1); then
		if [[ "$output" == *"docker logs"* ]] && [[ "$output" == *"--tail 10"* ]]; then
			log_pass "--tail flag properly parsed"
		else
			log_fail "--tail flag not properly parsed. Got: $output"
			return 1
		fi
	else
		log_fail "--tail flag parsing failed"
		return 1
	fi
}

# Test 10: Combined flags
test_combined_flags() {
	log_test "Testing combined flags"
	((TESTS_RUN++))

	# Create test container
	local container_name
	container_name=$(create_test_container "combinedtest")

	# Test combined flags in dry run
	if output=$("$DEVBOX_BIN" logs combinedtest --tail 50 --dry-run 2>&1); then
		if [[ "$output" == *"docker logs"* ]] && [[ "$output" == *"--tail 50"* ]]; then
			log_pass "Combined flags properly parsed"
		else
			log_fail "Combined flags not properly parsed. Got: $output"
			return 1
		fi
	else
		log_fail "Combined flags parsing failed"
		return 1
	fi
}

# Test 11: Too many arguments
test_too_many_args() {
	log_test "Testing too many arguments"
	((TESTS_RUN++))

	if output=$("$DEVBOX_BIN" logs container1 extra_arg 2>&1); then
		log_fail "Command should reject extra arguments"
		return 1
	else
		if [[ "$output" == *"Too many arguments"* ]] || [[ "$output" == *"Unexpected argument"* ]]; then
			log_pass "Extra arguments properly rejected"
		else
			log_fail "Error message incorrect. Got: $output"
			return 1
		fi
	fi
}

# Run all tests
echo "======================================"
echo "Running devbox logs command tests"
echo "======================================"
echo

test_help || true
test_missing_name || true
test_not_found || true
test_basic_logs || true
test_logs_by_id || true
test_stopped_container || true
test_dry_run || true
test_follow_flag || true
test_tail_option || true
test_combined_flags || true
test_too_many_args || true

# Print summary
echo
echo "======================================"
echo "Test Summary"
echo "======================================"
echo "Total tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
if [[ $TESTS_SKIPPED -gt 0 ]]; then
	echo -e "${BLUE}Skipped: $TESTS_SKIPPED${NC}"
fi
if [[ $TESTS_FAILED -gt 0 ]]; then
	echo -e "${RED}Failed: $TESTS_FAILED${NC}"
	exit 1
else
	echo -e "${GREEN}All tests passed!${NC}"
	exit 0
fi
