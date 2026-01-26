#!/bin/bash
set -euo pipefail

# Test suite for devbox list command
# Tests the container enumeration and formatting functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEVBOX_CLI="$PROJECT_ROOT/bin/devbox"

# Test constants
readonly TEST_CONTAINER_PREFIX="devbox-test-"
readonly TEST_IMAGE="alpine:latest"
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

# Helper function to create a test container with labels
create_test_container() {
    local name="$1"
    local repo="${2:-git@github.com:test/repo.git}"
    local mode="${3:-oauth}"
    local ports="${4:-}"
    local status="${5:-running}"

    local full_name="${TEST_CONTAINER_PREFIX}${name}"
    local labels="--label devbox.repo=$repo --label devbox.mode=$mode"

    if [[ -n "$ports" ]]; then
        labels="$labels --label devbox.ports=$ports"
    fi

    # Create container in desired state
    local run_opts="-d --name $full_name $labels"
    if [[ "$status" == "running" ]]; then
        run_opts="$run_opts -it"
    fi

    local container_id
    container_id=$(docker run $run_opts "$TEST_IMAGE" sleep 3600)
    CLEANUP_CONTAINERS+=("$container_id")

    # Stop container if we want it stopped
    if [[ "$status" == "exited" ]]; then
        docker stop "$container_id" >/dev/null
    fi

    echo "$container_id"
}

# Test functions
test_list_help() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local output

    if output=$("$DEVBOX_CLI" list --help 2>&1); then
        if [[ "$output" == *"List all devbox containers"* ]]; then
            log_test "list --help shows correct help text"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_fail "list --help missing expected content"
        fi
    else
        log_fail "list --help failed to run"
    fi
}

test_list_empty() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local output

    if output=$("$DEVBOX_CLI" list 2>&1); then
        # Check that no test containers are present (ignore production containers)
        if [[ "$output" != *"devbox-test-"* ]]; then
            log_test "list shows no test containers when test environment is clean"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_fail "list should show no test containers when test environment is clean"
            echo "Found test containers in output: $output"
        fi
    else
        log_fail "list command failed"
    fi
}

test_list_single_container() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local output

    # Create a single test container
    local container_id
    container_id=$(create_test_container "myapp" "git@github.com:org/myapp.git" "oauth" "3000:3000" "running")
    local short_id="${container_id:0:8}"

    if output=$("$DEVBOX_CLI" list 2>&1); then
        if [[ "$output" == *"myapp"* ]] && \
           [[ "$output" == *"$short_id"* ]] && \
           [[ "$output" == *"running"* ]] && \
           [[ "$output" == *"git@github.com:org/myapp.git"* ]] && \
           [[ "$output" == *"3000:3000"* ]] && \
           [[ "$output" == *"oauth"* ]]; then
            log_test "list shows single container with all fields"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_fail "list output missing expected container information"
            echo "Output was: $output"
        fi
    else
        log_fail "list command failed with single container"
    fi
}

test_list_multiple_containers() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local output

    # Create multiple test containers with different configurations
    create_test_container "app1" "git@github.com:org/app1.git" "oauth" "3000:3000" "running"
    create_test_container "app2" "git@github.com:org/app2.git" "bedrock" "" "exited"
    create_test_container "app3" "git@github.com:org/app3.git" "oauth" "8080:80,9000:9000" "running"

    if output=$("$DEVBOX_CLI" list 2>&1); then
        if [[ "$output" == *"app1"* ]] && \
           [[ "$output" == *"app2"* ]] && \
           [[ "$output" == *"app3"* ]] && \
           [[ "$output" == *"running"* ]] && \
           [[ "$output" == *"exited"* ]] && \
           [[ "$output" == *"oauth"* ]] && \
           [[ "$output" == *"bedrock"* ]] && \
           [[ "$output" == *"8080:80,9000:9000"* ]]; then
            log_test "list shows multiple containers with correct statuses and configurations"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_fail "list output missing expected information for multiple containers"
            echo "Output was: $output"
        fi
    else
        log_fail "list command failed with multiple containers"
    fi
}

test_list_header_format() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local output

    # Create at least one container to trigger table output
    create_test_container "test" "git@github.com:test/test.git" "oauth" "" "running"

    if output=$("$DEVBOX_CLI" list 2>&1); then
        if [[ "$output" == *"NAME"* ]] && \
           [[ "$output" == *"ID"* ]] && \
           [[ "$output" == *"STATUS"* ]] && \
           [[ "$output" == *"REPO"* ]] && \
           [[ "$output" == *"PORTS"* ]] && \
           [[ "$output" == *"MODE"* ]]; then
            log_test "list shows proper table header"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_fail "list missing expected table headers"
            echo "Output was: $output"
        fi
    else
        log_fail "list command failed when checking headers"
    fi
}

test_list_ignores_non_devbox_containers() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local output

    # Create a regular non-devbox container
    local regular_container
    regular_container=$(docker run -d --name test-regular alpine sleep 3600)
    CLEANUP_CONTAINERS+=("$regular_container")

    # Create a devbox container
    create_test_container "devbox-only" "git@github.com:test/test.git" "oauth" "" "running"

    if output=$("$DEVBOX_CLI" list 2>&1); then
        if [[ "$output" == *"devbox-only"* ]] && [[ "$output" != *"test-regular"* ]]; then
            log_test "list ignores non-devbox containers"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_fail "list should ignore non-devbox containers"
            echo "Output was: $output"
        fi
    else
        log_fail "list command failed when testing container filtering"
    fi
}

test_list_invalid_flag() {
    TESTS_RUN=$((TESTS_RUN + 1))
    local output exit_code

    output=$("$DEVBOX_CLI" list --invalid-flag 2>&1) || exit_code=$?

    if [[ $exit_code -ne 0 ]] && [[ "$output" == *"Unknown option"* ]]; then
        log_test "list rejects invalid flags with proper error"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_fail "list should reject invalid flags"
        echo "Output was: $output"
        echo "Exit code was: ${exit_code:-0}"
    fi
}

# Main test execution
main() {
    echo "Running devbox list command tests..."

    # Check prerequisites
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker not found, skipping tests"
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        echo "Docker daemon not running, skipping tests"
        exit 1
    fi

    # Alpine image should be available or will be pulled automatically

    # Clean up any leftover containers from previous runs
    initial_cleanup

    # Run tests
    test_list_help
    test_list_empty
    test_list_single_container
    test_list_multiple_containers
    test_list_header_format
    test_list_ignores_non_devbox_containers
    test_list_invalid_flag

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