#!/bin/bash

# Test suite for devbox rm command
# Tests container removal functionality with comprehensive scenarios

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
declare -a TEST_VOLUMES

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
	echo "Cleaning up test containers and volumes..."
	if [[ ${#TEST_CONTAINERS[@]} -gt 0 ]]; then
		for container in "${TEST_CONTAINERS[@]}"; do
			docker rm -f "$container" 2>/dev/null || true
		done
	fi
	if [[ ${#TEST_VOLUMES[@]} -gt 0 ]]; then
		for volume in "${TEST_VOLUMES[@]}"; do
			docker volume rm "$volume" 2>/dev/null || true
		done
	fi
}

# Set up cleanup trap
trap cleanup EXIT

# Helper function to create test container with workspace volume
create_test_container() {
	local name="$1"
	local state="${2:-running}"
	local container_name="devbox-test-${name}"
	local volume_name="${container_name}-workspace"

	# Create workspace volume
	docker volume create "$volume_name" >/dev/null 2>&1
	TEST_VOLUMES+=("$volume_name")

	# Create container with workspace volume mounted
	if [ "$state" = "running" ]; then
		docker run -dit --name "$container_name" \
			--label "devbox.repo=git@github.com:test/repo.git" \
			--label "devbox.mode=oauth" \
			--label "devbox.ports=" \
			-v "$volume_name:/workspace" \
			alpine:latest sleep 300 >/dev/null
	else
		# Create stopped container by starting and then stopping it
		docker run -dit --name "$container_name" \
			--label "devbox.repo=git@github.com:test/repo.git" \
			--label "devbox.mode=oauth" \
			--label "devbox.ports=" \
			-v "$volume_name:/workspace" \
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
	if output=$("$DEVBOX_BIN" rm --help 2>&1); then
		if [[ "$output" == *"Remove a container"* ]] && [[ "$output" == *"USAGE:"* ]] && [[ "$output" == *"--force"* ]]; then
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
	if output=$("$DEVBOX_BIN" rm --invalid-flag 2>&1); then
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

	if output=$("$DEVBOX_BIN" rm 2>&1); then
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

	if output=$("$DEVBOX_BIN" rm nonexistent-container 2>&1); then
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

# Test 4: Remove stopped container
test_remove_stopped_container() {
	log_test "Testing removal of stopped container"
	((TESTS_RUN++))

	# Create stopped test container
	container=$(create_test_container "rm-stopped-test" "stopped")
	volume_name="${container}-workspace"

	# Remove the container (pipe 'y' to confirm)
	if output=$(echo "y" | "$DEVBOX_BIN" rm rm-stopped-test 2>&1); then
		# Verify container is removed
		if docker inspect "$container" >/dev/null 2>&1; then
			log_fail "Container still exists after removal"
			return 1
		else
			# Verify workspace volume is also removed
			if docker volume inspect "$volume_name" >/dev/null 2>&1; then
				log_fail "Workspace volume still exists after container removal"
				return 1
			else
				log_pass "Container and workspace volume successfully removed"
				# Remove from TEST_CONTAINERS and TEST_VOLUMES since they're now gone
				TEST_CONTAINERS=(${TEST_CONTAINERS[@]/$container/})
				TEST_VOLUMES=(${TEST_VOLUMES[@]/$volume_name/})
			fi
		fi
	else
		log_fail "Remove command failed. Output: $output"
		return 1
	fi
}

# Test 5: Attempt to remove running container without force
test_remove_running_without_force() {
	log_test "Testing removal of running container without --force flag"
	((TESTS_RUN++))

	# Create running test container
	container=$(create_test_container "rm-running-test")

	# Try to remove running container without force
	if output=$("$DEVBOX_BIN" rm rm-running-test 2>&1); then
		log_fail "Removing running container should have failed without --force"
		return 1
	else
		if [[ "$output" == *"Container 'rm-running-test' is running"* ]] && [[ "$output" == *"use --force"* ]]; then
			# Verify container still exists
			if docker inspect "$container" >/dev/null 2>&1; then
				log_pass "Running container removal properly blocked without --force"
			else
				log_fail "Container was removed despite error message"
				return 1
			fi
		else
			log_fail "Error message incorrect for running container. Got: $output"
			return 1
		fi
	fi
}

# Test 6: Force remove running container
test_force_remove_running_container() {
	log_test "Testing force removal of running container"
	((TESTS_RUN++))

	# Create running test container
	container=$(create_test_container "rm-force-test")
	volume_name="${container}-workspace"

	# Force remove the running container
	if output=$("$DEVBOX_BIN" rm --force rm-force-test 2>&1); then
		# Verify container is removed
		if docker inspect "$container" >/dev/null 2>&1; then
			log_fail "Container still exists after force removal"
			return 1
		else
			# Verify workspace volume is also removed
			if docker volume inspect "$volume_name" >/dev/null 2>&1; then
				log_fail "Workspace volume still exists after force removal"
				return 1
			else
				log_pass "Running container and workspace volume force removed successfully"
				# Remove from TEST_CONTAINERS and TEST_VOLUMES since they're now gone
				TEST_CONTAINERS=(${TEST_CONTAINERS[@]/$container/})
				TEST_VOLUMES=(${TEST_VOLUMES[@]/$volume_name/})
			fi
		fi
	else
		log_fail "Force remove command failed. Output: $output"
		return 1
	fi
}

# Test 7: Container ID resolution
test_container_id_resolution() {
	log_test "Testing container ID resolution"
	((TESTS_RUN++))

	# Create test container
	container=$(create_test_container "rm-id-test" "stopped")
	container_id=$(docker inspect --format '{{.Id}}' "$container")
	short_id="${container_id:0:12}"
	volume_name="${container}-workspace"

	# Remove using short ID (pipe 'y' to confirm)
	if output=$(echo "y" | "$DEVBOX_BIN" rm "$short_id" 2>&1); then
		# Verify container is removed
		if docker inspect "$container" >/dev/null 2>&1; then
			log_fail "Container still exists after ID removal"
			return 1
		else
			log_pass "Container ID resolution and removal successful"
			# Remove from TEST_CONTAINERS and TEST_VOLUMES since they're now gone
			TEST_CONTAINERS=(${TEST_CONTAINERS[@]/$container/})
			TEST_VOLUMES=(${TEST_VOLUMES[@]/$volume_name/})
		fi
	else
		log_fail "Remove by container ID failed. Output: $output"
		return 1
	fi
}

# Test 8: Dry run mode
test_dry_run() {
	log_test "Testing dry run mode"
	((TESTS_RUN++))

	# Create test container
	container=$(create_test_container "rm-dry-run-test" "stopped")

	# Test dry run
	if output=$("$DEVBOX_BIN" rm --dry-run rm-dry-run-test 2>&1); then
		if [[ "$output" == *"Would run:"* ]] && [[ "$output" == *"docker rm"* ]]; then
			# Verify container still exists
			if docker inspect "$container" >/dev/null 2>&1; then
				log_pass "Dry run mode working correctly"
			else
				log_fail "Dry run actually removed container"
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

# Test 9: Extra arguments rejection
test_extra_arguments() {
	log_test "Testing extra arguments rejection"
	((TESTS_RUN++))

	if output=$("$DEVBOX_BIN" rm container1 container2 extra 2>&1); then
		log_fail "Extra arguments should have failed but didn't"
		return 1
	else
		if [[ "$output" == *"Too many arguments"* ]]; then
			log_pass "Extra arguments properly rejected"
		else
			log_fail "Extra arguments error message incorrect. Got: $output"
			return 1
		fi
	fi
}

# Test 10: Force flag with dry run
test_force_dry_run() {
	log_test "Testing --force flag with dry run"
	((TESTS_RUN++))

	# Create running test container
	container=$(create_test_container "rm-force-dry-run-test")

	# Test force dry run
	if output=$("$DEVBOX_BIN" rm --force --dry-run rm-force-dry-run-test 2>&1); then
		if [[ "$output" == *"Would run:"* ]] && [[ "$output" == *"docker rm -f"* ]]; then
			# Verify container still exists and running
			if status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null); then
				if [[ "$status" == "running" ]]; then
					log_pass "Force dry run mode working correctly"
				else
					log_fail "Force dry run changed container state"
					return 1
				fi
			else
				log_fail "Container missing after force dry run"
				return 1
			fi
		else
			log_fail "Force dry run output incorrect. Got: $output"
			return 1
		fi
	else
		log_fail "Force dry run failed. Output: $output"
		return 1
	fi
}

# Test 11: Confirmation prompt for single container removal (denied)
test_confirm_prompt_denied() {
	log_test "Testing confirmation prompt when user declines removal"
	((TESTS_RUN++))

	# Create stopped test container
	container=$(create_test_container "rm-confirm-deny-test" "stopped")

	# Pipe 'n' (no) to stdin to deny confirmation
	output=$(echo "n" | "$DEVBOX_BIN" rm rm-confirm-deny-test 2>&1) || true

	if [[ "$output" == *"Operation cancelled"* ]]; then
		# Verify container still exists (was NOT removed)
		if docker inspect "$container" >/dev/null 2>&1; then
			log_pass "Confirmation prompt properly cancelled removal"
		else
			log_fail "Container was removed despite cancellation"
			return 1
		fi
	else
		log_fail "Expected 'Operation cancelled' message. Got: $output"
		return 1
	fi
}

# Test 12: Confirmation prompt for single container removal (confirmed)
test_confirm_prompt_confirmed() {
	log_test "Testing confirmation prompt when user confirms removal"
	((TESTS_RUN++))

	# Create stopped test container
	container=$(create_test_container "rm-confirm-yes-test" "stopped")
	volume_name="${container}-workspace"

	# Pipe 'y' (yes) to stdin to confirm removal
	if output=$(echo "y" | "$DEVBOX_BIN" rm rm-confirm-yes-test 2>&1); then
		# Verify container is removed
		if docker inspect "$container" >/dev/null 2>&1; then
			log_fail "Container still exists after confirmed removal"
			return 1
		else
			log_pass "Confirmation prompt properly allowed removal"
			# Remove from TEST_CONTAINERS and TEST_VOLUMES since they're now gone
			TEST_CONTAINERS=(${TEST_CONTAINERS[@]/$container/})
			TEST_VOLUMES=(${TEST_VOLUMES[@]/$volume_name/})
		fi
	else
		log_fail "Remove command failed after confirmation. Output: $output"
		return 1
	fi
}

# Test 13: Force flag skips confirmation prompt
test_force_skips_confirmation() {
	log_test "Testing that --force flag skips confirmation prompt"
	((TESTS_RUN++))

	# Create stopped test container
	container=$(create_test_container "rm-force-skip-test" "stopped")
	volume_name="${container}-workspace"

	# Use --force which should skip the prompt entirely (no stdin needed)
	if output=$("$DEVBOX_BIN" rm --force rm-force-skip-test 2>&1); then
		# Verify container is removed
		if docker inspect "$container" >/dev/null 2>&1; then
			log_fail "Container still exists after force removal"
			return 1
		else
			log_pass "Force flag properly skipped confirmation"
			# Remove from TEST_CONTAINERS and TEST_VOLUMES since they're now gone
			TEST_CONTAINERS=(${TEST_CONTAINERS[@]/$container/})
			TEST_VOLUMES=(${TEST_VOLUMES[@]/$volume_name/})
		fi
	else
		log_fail "Force remove command failed. Output: $output"
		return 1
	fi
}

# Test 14: Confirmation prompt shows container info
test_confirm_prompt_shows_info() {
	log_test "Testing confirmation prompt displays container information"
	((TESTS_RUN++))

	# Create stopped test container
	container=$(create_test_container "rm-confirm-info-test" "stopped")

	# Pipe 'n' to cancel and capture output
	output=$(echo "n" | "$DEVBOX_BIN" rm rm-confirm-info-test 2>&1) || true

	# Check that prompt shows container name and warning
	if [[ "$output" == *"rm-confirm-info-test"* ]] && [[ "$output" == *"irreversible"* ]]; then
		log_pass "Confirmation prompt shows container info"
	else
		log_fail "Confirmation prompt missing container info. Got: $output"
		return 1
	fi
}

# Main test runner
main() {
	echo "Running devbox rm command tests..."
	echo "=================================="

	# Check if Docker is available
	if ! docker info >/dev/null 2>&1; then
		echo "Docker is not available. Skipping tests."
		exit 0
	fi

	# Run tests
	test_help || true
	test_missing_argument || true
	test_nonexistent_container || true
	test_remove_stopped_container || true
	test_remove_running_without_force || true
	test_force_remove_running_container || true
	test_container_id_resolution || true
	test_dry_run || true
	test_extra_arguments || true
	test_force_dry_run || true
	test_confirm_prompt_denied || true
	test_confirm_prompt_confirmed || true
	test_force_skips_confirmation || true
	test_confirm_prompt_shows_info || true

	# Print summary
	echo
	echo "=================================="
	echo "Test Summary:"
	echo "  Ran: $TESTS_RUN"
	echo "  Passed: $TESTS_PASSED"
	echo "  Failed: $TESTS_FAILED"
	echo "  Skipped: $TESTS_SKIPPED"
	echo "=================================="

	if [ $TESTS_FAILED -gt 0 ]; then
		exit 1
	fi
}

# Run main function
main "$@"
