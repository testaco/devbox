#!/bin/bash
# Test suite for devbox ports command

set -euo pipefail

# Source test utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEVBOX_BIN="$PROJECT_ROOT/bin/devbox"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test containers array for cleanup
declare -a TEST_CONTAINERS=()

# Logging functions
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

# Check if Docker is available
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_skip "Docker is not running. Skipping all tests."
        exit 0
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test containers..."
    for container in "${TEST_CONTAINERS[@]}"; do
        docker rm -f "$container" >/dev/null 2>&1 || true
    done
}

# Setup trap for cleanup
trap cleanup EXIT

# Helper function to create a test container
create_test_container() {
    local name="$1"
    local port_args="${2:-}"
    local container_name="devbox-test-${name}"

    # Remove container if it already exists
    docker rm -f "$container_name" >/dev/null 2>&1 || true

    # Create a simple container with optional port mappings
    local cmd="docker run -d --name $container_name"

    if [[ -n "$port_args" ]]; then
        cmd="$cmd $port_args"
    fi

    cmd="$cmd alpine:latest sleep 3600"

    if eval "$cmd" >/dev/null 2>&1; then
        TEST_CONTAINERS+=("$container_name")
        echo "$container_name"
    else
        return 1
    fi
}

#
# Test 1: Help flag displays usage
#
test_help_flag() {
    log_test "Testing ports --help flag"
    ((TESTS_RUN++))

    if output=$("$DEVBOX_BIN" ports --help 2>&1); then
        if [[ "$output" == *"devbox ports"* ]] && [[ "$output" == *"USAGE"* ]]; then
            log_pass "Help flag displays usage information"
        else
            log_fail "Help output missing expected content"
            return 1
        fi
    else
        log_fail "Help flag failed"
        return 1
    fi
}

#
# Test 2: Help with -h flag
#
test_help_short_flag() {
    log_test "Testing ports -h flag"
    ((TESTS_RUN++))

    if output=$("$DEVBOX_BIN" ports -h 2>&1); then
        if [[ "$output" == *"devbox ports"* ]]; then
            log_pass "Short help flag works"
        else
            log_fail "Short help flag output incorrect"
            return 1
        fi
    else
        log_fail "Short help flag failed"
        return 1
    fi
}

#
# Test 3: Missing container argument shows error
#
test_missing_argument() {
    log_test "Testing ports with missing container argument"
    ((TESTS_RUN++))

    if output=$("$DEVBOX_BIN" ports 2>&1); then
        log_fail "Should have failed with missing argument: $output"
        return 1
    else
        if [[ "$output" == *"required"* ]] || [[ "$output" == *"Usage"* ]]; then
            log_pass "Missing argument shows appropriate error"
        else
            log_fail "Error message unclear: $output"
            return 1
        fi
    fi
}

#
# Test 4: Nonexistent container shows error
#
test_nonexistent_container() {
    log_test "Testing ports with nonexistent container"
    ((TESTS_RUN++))

    if output=$("$DEVBOX_BIN" ports nonexistent-container-12345 2>&1); then
        log_fail "Should have failed for nonexistent container: $output"
        return 1
    else
        if [[ "$output" == *"not found"* ]]; then
            log_pass "Nonexistent container shows appropriate error"
        else
            log_fail "Error message unclear: $output"
            return 1
        fi
    fi
}

#
# Test 5: Container with no ports
#
test_container_no_ports() {
    log_test "Testing ports for container with no port mappings"
    ((TESTS_RUN++))

    # Create container without port mappings
    container=$(create_test_container "noports")

    if output=$("$DEVBOX_BIN" ports "${container#devbox-test-}" 2>&1); then
        if [[ "$output" == *"no port"* ]] || [[ "$output" == *"No port"* ]]; then
            log_pass "Container with no ports handled correctly"
        else
            log_fail "Unexpected output for no ports: $output"
            return 1
        fi
    else
        log_fail "Command failed: $output"
        return 1
    fi
}

#
# Test 6: Container with single port mapping
#
test_container_single_port() {
    log_test "Testing ports for container with single port mapping"
    ((TESTS_RUN++))

    # Create container with single port mapping
    container=$(create_test_container "oneport" "-p 18080:80")

    if output=$("$DEVBOX_BIN" ports "${container#devbox-test-}" 2>&1); then
        if [[ "$output" == *"18080"* ]] && [[ "$output" == *"80"* ]]; then
            log_pass "Single port mapping displayed correctly"
        else
            log_fail "Port mapping not displayed: $output"
            return 1
        fi
    else
        log_fail "Command failed: $output"
        return 1
    fi
}

#
# Test 7: Container with multiple port mappings
#
test_container_multiple_ports() {
    log_test "Testing ports for container with multiple port mappings"
    ((TESTS_RUN++))

    # Create container with multiple port mappings
    container=$(create_test_container "multiport" "-p 13000:3000 -p 18081:80")

    if output=$("$DEVBOX_BIN" ports "${container#devbox-test-}" 2>&1); then
        if [[ "$output" == *"13000"* ]] && [[ "$output" == *"3000"* ]] && [[ "$output" == *"18081"* ]] && [[ "$output" == *"80"* ]]; then
            log_pass "Multiple port mappings displayed correctly"
        else
            log_fail "Not all ports displayed: $output"
            return 1
        fi
    else
        log_fail "Command failed: $output"
        return 1
    fi
}

#
# Test 8: Dry-run mode
#
test_dry_run_mode() {
    log_test "Testing ports with --dry-run flag"
    ((TESTS_RUN++))

    container=$(create_test_container "dryrun" "-p 19000:9000")

    if output=$("$DEVBOX_BIN" ports "${container#devbox-test-}" --dry-run 2>&1); then
        if [[ "$output" == *"Would"* ]] || [[ "$output" == *"would"* ]]; then
            log_pass "Dry-run mode works"
        else
            log_fail "Dry-run output unclear: $output"
            return 1
        fi
    else
        log_fail "Dry-run failed: $output"
        return 1
    fi
}

#
# Test 9: Container ID instead of name
#
test_container_by_id() {
    log_test "Testing ports with container ID"
    ((TESTS_RUN++))

    container=$(create_test_container "byid" "-p 17000:7000")
    container_id=$(docker ps -q --filter "name=$container")
    short_id="${container_id:0:12}"

    if output=$("$DEVBOX_BIN" ports "$short_id" 2>&1); then
        if [[ "$output" == *"17000"* ]] && [[ "$output" == *"7000"* ]]; then
            log_pass "Container ID lookup works"
        else
            log_fail "Port not displayed with ID lookup: $output"
            return 1
        fi
    else
        log_fail "Container ID lookup failed: $output"
        return 1
    fi
}

#
# Test 10: Unknown flag shows error
#
test_unknown_flag() {
    log_test "Testing ports with unknown flag"
    ((TESTS_RUN++))

    if output=$("$DEVBOX_BIN" ports testcontainer --unknown-flag 2>&1); then
        log_fail "Should have failed with unknown flag: $output"
        return 1
    else
        if [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"unknown"* ]]; then
            log_pass "Unknown flag shows appropriate error"
        else
            log_fail "Error message unclear: $output"
            return 1
        fi
    fi
}

#
# Test 11: Stopped container still shows ports
#
test_stopped_container() {
    log_test "Testing ports for stopped container"
    ((TESTS_RUN++))

    container=$(create_test_container "stopped" "-p 15000:5000")
    docker stop "$container" >/dev/null 2>&1

    if output=$("$DEVBOX_BIN" ports "${container#devbox-test-}" 2>&1); then
        if [[ "$output" == *"15000"* ]] && [[ "$output" == *"5000"* ]]; then
            log_pass "Stopped container ports displayed correctly"
        else
            log_fail "Ports not displayed for stopped container: $output"
            return 1
        fi
    else
        log_fail "Command failed for stopped container: $output"
        return 1
    fi
}

#
# Main test execution
#
main() {
    echo "======================================"
    echo "Devbox Ports Command Test Suite"
    echo "======================================"
    echo

    # Check Docker availability
    check_docker

    # Run all tests
    test_help_flag || true
    test_help_short_flag || true
    test_missing_argument || true
    test_nonexistent_container || true
    test_container_no_ports || true
    test_container_single_port || true
    test_container_multiple_ports || true
    test_dry_run_mode || true
    test_container_by_id || true
    test_unknown_flag || true
    test_stopped_container || true

    # Print summary
    echo
    echo "======================================"
    echo "Test Summary"
    echo "======================================"
    echo "Total tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo "======================================"

    # Exit with appropriate code
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run tests
main "$@"
