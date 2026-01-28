#!/bin/bash
# Test suite for devbox start command

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEVBOX_CLI="$PROJECT_ROOT/bin/devbox"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Container tracking for cleanup
TEST_CONTAINERS=()

# Logging functions
log_test() {
    echo -e "${YELLOW}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "[INFO] $*"
}

# Test helper to create a stopped container for testing
create_test_container() {
    local container_name="$1"
    local full_name="devbox-test-$container_name"

    # Remove existing container if it exists
    docker rm -f "$full_name" >/dev/null 2>&1 || true

    # Create and start container, then stop it
    if docker run -dit \
        --name "$full_name" \
        --label devbox.repo="git@github.com:test/repo.git" \
        --label devbox.mode="oauth" \
        alpine:latest \
        sh >/dev/null 2>&1; then

        # Stop the container to put it in stopped state
        docker stop "$full_name" >/dev/null 2>&1

        TEST_CONTAINERS+=("$full_name")
        return 0
    else
        return 1
    fi
}

# Cleanup function
cleanup_test_containers() {
    for container in "${TEST_CONTAINERS[@]}"; do
        docker rm -f "$container" >/dev/null 2>&1 || true
    done
    TEST_CONTAINERS=()
}

# Run a single test
run_test() {
    local test_name="$1"
    local test_func="$2"

    log_test "$test_name"
    ((TESTS_RUN++))

    if $test_func; then
        log_pass "$test_name"
    else
        log_fail "$test_name"
    fi

    # Clean up after each test
    cleanup_test_containers
    echo
}

# Test 1: Help text validation
test_help_text() {
    local output
    output=$("$DEVBOX_CLI" start --help 2>&1)

    if [[ "$output" == *"devbox start - Start a stopped container"* ]] && \
       [[ "$output" == *"USAGE:"* ]] && \
       [[ "$output" == *"<name|id>"* ]] && \
       [[ "$output" == *"EXAMPLES:"* ]]; then
        return 0
    else
        echo "Expected help text not found in output:"
        echo "$output"
        return 1
    fi
}

# Test 2: Missing argument handling
test_missing_argument() {
    local output
    output=$("$DEVBOX_CLI" start 2>&1 || true)

    if [[ "$output" == *"Container name or ID is required"* ]] && \
       [[ "$output" == *"Usage: devbox start <name|id>"* ]]; then
        return 0
    else
        echo "Expected error message not found in output:"
        echo "$output"
        return 1
    fi
}

# Test 3: Invalid flag handling
test_invalid_flag() {
    local output
    output=$("$DEVBOX_CLI" start --invalid-flag 2>&1 || true)

    if [[ "$output" == *"Unknown option: --invalid-flag"* ]]; then
        return 0
    else
        echo "Expected error message not found in output:"
        echo "$output"
        return 1
    fi
}

# Test 4: Nonexistent container
test_nonexistent_container() {
    local output
    output=$("$DEVBOX_CLI" start nonexistent-container 2>&1 || true)

    if [[ "$output" == *"Container 'nonexistent-container' not found"* ]] && \
       [[ "$output" == *"Use 'devbox list' to see available containers"* ]]; then
        return 0
    else
        echo "Expected error message not found in output:"
        echo "$output"
        return 1
    fi
}

# Test 5: Start stopped container
test_start_stopped_container() {
    # Create a stopped test container
    if ! create_test_container "starttest"; then
        echo "Failed to create test container"
        return 1
    fi

    local output
    output=$("$DEVBOX_CLI" start starttest 2>&1)

    if [[ "$output" == *"Container 'starttest' started successfully"* ]]; then
        # Verify container is actually running
        local status
        status=$(docker inspect --format '{{.State.Status}}' "devbox-test-starttest" 2>/dev/null || echo "unknown")
        if [[ "$status" == "running" ]]; then
            return 0
        else
            echo "Container was not actually started (status: $status)"
            return 1
        fi
    else
        echo "Expected success message not found in output:"
        echo "$output"
        return 1
    fi
}

# Test 6: Start already running container (graceful handling)
test_start_running_container() {
    # Create a test container and ensure it's running
    if ! docker run -dit \
        --name "devbox-test-runningtest" \
        --label devbox.repo="git@github.com:test/repo.git" \
        --label devbox.mode="oauth" \
        alpine:latest \
        sh >/dev/null 2>&1; then
        echo "Failed to create running test container"
        return 1
    fi

    TEST_CONTAINERS+=("devbox-test-runningtest")

    local output
    output=$("$DEVBOX_CLI" start runningtest 2>&1)

    if [[ "$output" == *"Container 'runningtest' is already running"* ]]; then
        return 0
    else
        echo "Expected already running message not found in output:"
        echo "$output"
        return 1
    fi
}

# Test 7: Container ID resolution
test_container_id_resolution() {
    # Create a stopped test container
    if ! create_test_container "idtest"; then
        echo "Failed to create test container"
        return 1
    fi

    # Get container ID
    local container_id
    container_id=$(docker ps -aq --filter "name=^devbox-test-idtest$")
    local short_id="${container_id:0:8}"

    local output
    output=$("$DEVBOX_CLI" start "$short_id" 2>&1)

    if [[ "$output" == *"Container 'idtest' started successfully"* ]]; then
        return 0
    else
        echo "Expected success message not found when using container ID:"
        echo "$output"
        return 1
    fi
}

# Test 8: Dry-run functionality
test_dry_run() {
    # Create a stopped test container
    if ! create_test_container "dryruntest"; then
        echo "Failed to create test container"
        return 1
    fi

    local output
    output=$("$DEVBOX_CLI" start dryruntest --dry-run 2>&1)

    if [[ "$output" == *"Would run: docker start"* ]] && \
       [[ "$output" == *"Container 'dryruntest'"* ]] && \
       [[ "$output" == *"current status:"* ]]; then
        # Verify container wasn't actually started
        local status
        status=$(docker inspect --format '{{.State.Status}}' "devbox-test-dryruntest" 2>/dev/null || echo "unknown")
        if [[ "$status" == "exited" ]]; then
            return 0
        else
            echo "Container was actually started during dry-run (status: $status)"
            return 1
        fi
    else
        echo "Expected dry-run output not found:"
        echo "$output"
        return 1
    fi
}

# Test 9: Too many arguments
test_too_many_arguments() {
    local output
    output=$("$DEVBOX_CLI" start container1 container2 2>&1 || true)

    if [[ "$output" == *"Too many arguments. Expected exactly 1 argument."* ]]; then
        return 0
    else
        echo "Expected error message not found in output:"
        echo "$output"
        return 1
    fi
}

# Main execution
main() {
    echo "Running devbox start command tests..."
    echo

    # Verify Docker is available
    if ! docker info >/dev/null 2>&1; then
        echo "Docker is not available. Skipping tests."
        exit 0
    fi

    # Run all tests
    run_test "Help text validation" test_help_text
    run_test "Missing argument handling" test_missing_argument
    run_test "Invalid flag handling" test_invalid_flag
    run_test "Nonexistent container error" test_nonexistent_container
    run_test "Start stopped container" test_start_stopped_container
    run_test "Start already running container (graceful)" test_start_running_container
    run_test "Container ID resolution" test_container_id_resolution
    run_test "Dry-run functionality" test_dry_run
    run_test "Too many arguments handling" test_too_many_arguments

    # Final cleanup
    cleanup_test_containers

    # Print summary
    echo "Test Results:"
    echo "  Total: $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
        exit 1
    else
        echo -e "  ${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

# Cleanup on exit
trap cleanup_test_containers EXIT

main "$@"