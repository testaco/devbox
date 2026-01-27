#!/bin/bash
# Test suite for devbox exec command

set -euo pipefail

# Colors for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVBOX_BIN="$SCRIPT_DIR/../bin/devbox"

# Helper functions
log_test() {
    echo -e "${BLUE}TEST:${NC} $*"
}

log_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $*"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}✗ FAIL:${NC} $*"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}⊘ SKIP:${NC} $*"
}

log_info() {
    echo -e "${BLUE}INFO:${NC} $*"
}

# Test helper: Create a test container
create_test_container() {
    local name="$1"
    local container_name="devbox-${name}"

    # Create a minimal running container
    docker run -dit \
        --name "$container_name" \
        --label devbox.name="$name" \
        alpine:latest \
        sh -c "sleep 3600" > /dev/null 2>&1

    echo "$container_name"
}

# Test helper: Remove test container
remove_test_container() {
    local container="$1"
    docker rm -f "$container" > /dev/null 2>&1 || true
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test containers..."
    docker ps -a --filter "label=devbox.name" --format "{{.Names}}" | grep "^devbox-test-exec-" | while read -r container; do
        remove_test_container "$container"
    done || true
}

# Run cleanup on exit
trap cleanup EXIT

# Test 1: Help flag shows usage
test_help_flag() {
    log_test "Help flag shows usage"
    ((TESTS_RUN++))

    if output=$("$DEVBOX_BIN" exec --help 2>&1); then
        if [[ "$output" == *"USAGE:"* ]] && [[ "$output" == *"devbox exec"* ]] && [[ "$output" == *"Execute a command"* ]]; then
            log_pass "Help text displayed correctly"
        else
            log_fail "Help text missing expected content: $output"
            return 1
        fi
    else
        log_fail "Help command failed"
        return 1
    fi
}

# Test 2: Missing container name shows error
test_missing_container() {
    log_test "Missing container name shows error"
    ((TESTS_RUN++))

    if output=$("$DEVBOX_BIN" exec 2>&1); then
        log_fail "Should have failed with missing container: $output"
        return 1
    else
        if [[ "$output" == *"container name"* ]] || [[ "$output" == *"required"* ]]; then
            log_pass "Correct error for missing container"
        else
            log_fail "Wrong error message: $output"
            return 1
        fi
    fi
}

# Test 3: Missing command shows error
test_missing_command() {
    log_test "Missing command shows error"
    ((TESTS_RUN++))

    if output=$("$DEVBOX_BIN" exec testcontainer 2>&1); then
        log_fail "Should have failed with missing command: $output"
        return 1
    else
        if [[ "$output" == *"command"* ]] || [[ "$output" == *"required"* ]]; then
            log_pass "Correct error for missing command"
        else
            log_fail "Wrong error message: $output"
            return 1
        fi
    fi
}

# Test 4: Nonexistent container shows error
test_nonexistent_container() {
    log_test "Nonexistent container shows error"
    ((TESTS_RUN++))

    if output=$("$DEVBOX_BIN" exec nonexistent-container echo test 2>&1); then
        log_fail "Should have failed with nonexistent container: $output"
        return 1
    else
        if [[ "$output" == *"not found"* ]] || [[ "$output" == *"No such container"* ]]; then
            log_pass "Correct error for nonexistent container"
        else
            log_fail "Wrong error message: $output"
            return 1
        fi
    fi
}

# Test 5: Execute simple command in running container
test_exec_simple_command() {
    log_test "Execute simple command in running container"
    ((TESTS_RUN++))

    local container=$(create_test_container "test-exec-simple")

    if output=$("$DEVBOX_BIN" exec test-exec-simple echo "hello world" 2>&1); then
        if [[ "$output" == *"hello world"* ]]; then
            log_pass "Command executed successfully"
        else
            log_fail "Unexpected output: $output"
            remove_test_container "$container"
            return 1
        fi
    else
        log_fail "Command execution failed: $output"
        remove_test_container "$container"
        return 1
    fi

    remove_test_container "$container"
}

# Test 6: Execute command with multiple arguments
test_exec_multiple_args() {
    log_test "Execute command with multiple arguments"
    ((TESTS_RUN++))

    local container=$(create_test_container "test-exec-multiarg")

    if output=$("$DEVBOX_BIN" exec test-exec-multiarg sh -c "echo arg1 arg2 arg3" 2>&1); then
        if [[ "$output" == *"arg1 arg2 arg3"* ]]; then
            log_pass "Command with multiple arguments executed"
        else
            log_fail "Unexpected output: $output"
            remove_test_container "$container"
            return 1
        fi
    else
        log_fail "Command execution failed: $output"
        remove_test_container "$container"
        return 1
    fi

    remove_test_container "$container"
}

# Test 7: Execute command using container ID
test_exec_by_id() {
    log_test "Execute command using container ID"
    ((TESTS_RUN++))

    local container=$(create_test_container "test-exec-byid")
    local container_id=$(docker inspect --format='{{.Id}}' "$container" | cut -c1-12)

    if output=$("$DEVBOX_BIN" exec "$container_id" echo "id-test" 2>&1); then
        if [[ "$output" == *"id-test"* ]]; then
            log_pass "Command executed using container ID"
        else
            log_fail "Unexpected output: $output"
            remove_test_container "$container"
            return 1
        fi
    else
        log_fail "Command execution failed: $output"
        remove_test_container "$container"
        return 1
    fi

    remove_test_container "$container"
}

# Test 8: Execute command in stopped container fails
test_exec_stopped_container() {
    log_test "Execute command in stopped container fails"
    ((TESTS_RUN++))

    local container=$(create_test_container "test-exec-stopped")
    docker stop "$container" > /dev/null 2>&1

    if output=$("$DEVBOX_BIN" exec test-exec-stopped echo test 2>&1); then
        log_fail "Should have failed with stopped container: $output"
        remove_test_container "$container"
        return 1
    else
        if [[ "$output" == *"not running"* ]] || [[ "$output" == *"is not running"* ]]; then
            log_pass "Correct error for stopped container"
        else
            log_fail "Wrong error message: $output"
            remove_test_container "$container"
            return 1
        fi
    fi

    remove_test_container "$container"
}

# Test 9: Dry-run mode shows command without executing
test_dry_run() {
    log_test "Dry-run mode shows command without executing"
    ((TESTS_RUN++))

    local container=$(create_test_container "test-exec-dryrun")

    if output=$("$DEVBOX_BIN" exec --dry-run test-exec-dryrun echo test 2>&1); then
        if [[ "$output" == *"docker exec"* ]] && [[ "$output" == *"echo test"* ]]; then
            log_pass "Dry-run shows command correctly"
        else
            log_fail "Dry-run output unexpected: $output"
            remove_test_container "$container"
            return 1
        fi
    else
        log_fail "Dry-run failed: $output"
        remove_test_container "$container"
        return 1
    fi

    remove_test_container "$container"
}

# Test 10: Invalid flag shows error
test_invalid_flag() {
    log_test "Invalid flag shows error"
    ((TESTS_RUN++))

    if output=$("$DEVBOX_BIN" exec --invalid-flag test echo test 2>&1); then
        log_fail "Should have failed with invalid flag: $output"
        return 1
    else
        if [[ "$output" == *"Unknown option"* ]] || [[ "$output" == *"invalid"* ]]; then
            log_pass "Correct error for invalid flag"
        else
            log_fail "Wrong error message: $output"
            return 1
        fi
    fi
}

# Test 11: Interactive flag is passed through
test_interactive_flag() {
    log_test "Interactive flag (-it) is passed through in dry-run"
    ((TESTS_RUN++))

    local container=$(create_test_container "test-exec-interactive")

    if output=$("$DEVBOX_BIN" exec --dry-run -it test-exec-interactive sh 2>&1); then
        if [[ "$output" == *"docker exec -it"* ]]; then
            log_pass "Interactive flag passed through correctly"
        else
            log_fail "Interactive flag not in command: $output"
            remove_test_container "$container"
            return 1
        fi
    else
        log_fail "Dry-run failed: $output"
        remove_test_container "$container"
        return 1
    fi

    remove_test_container "$container"
}

# Run all tests
main() {
    echo "======================================="
    echo "Devbox Exec Command Test Suite"
    echo "======================================="
    echo ""

    test_help_flag || true
    test_missing_container || true
    test_missing_command || true
    test_nonexistent_container || true
    test_exec_simple_command || true
    test_exec_multiple_args || true
    test_exec_by_id || true
    test_exec_stopped_container || true
    test_dry_run || true
    test_invalid_flag || true
    test_interactive_flag || true

    echo ""
    echo "======================================="
    echo "Test Results"
    echo "======================================="
    echo -e "Total tests run: ${BLUE}${TESTS_RUN}${NC}"
    echo -e "Tests passed:    ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests failed:    ${RED}${TESTS_FAILED}${NC}"
    echo ""

    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        exit 1
    fi
}

main "$@"
