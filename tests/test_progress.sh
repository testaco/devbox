#!/bin/bash
# Tests for progress indicator functions

# Colors for test output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_SKIPPED=0

# Helper functions
log_test() {
	echo -e "Running: $1"
}

log_pass() {
	echo -e "${GREEN}✓ PASS:${NC} $1"
	((TESTS_PASSED++)) || true
}

log_fail() {
	echo -e "${RED}✗ FAIL:${NC} $1"
}

log_skip() {
	echo -e "${YELLOW}○ SKIP:${NC} $1"
	((TESTS_SKIPPED++)) || true
}

# Source the progress library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROGRESS_LIB="$PROJECT_ROOT/lib/progress.sh"

# Test: Library file exists
test_library_exists() {
	log_test "Progress library file exists"
	((TESTS_RUN++)) || true

	if [[ -f "$PROGRESS_LIB" ]]; then
		log_pass "Library file exists at $PROGRESS_LIB"
	else
		log_fail "Library file not found at $PROGRESS_LIB"
		return 1
	fi
}

# Test: Library can be sourced without errors
test_library_sources() {
	log_test "Progress library sources without errors"
	((TESTS_RUN++)) || true

	if source "$PROGRESS_LIB" 2>/dev/null; then
		log_pass "Library sources successfully"
	else
		log_fail "Library failed to source"
		return 1
	fi
}

# Test: start_spinner function exists
test_start_spinner_exists() {
	log_test "start_spinner function exists"
	((TESTS_RUN++)) || true

	source "$PROGRESS_LIB"
	if declare -f start_spinner >/dev/null 2>&1; then
		log_pass "start_spinner function exists"
	else
		log_fail "start_spinner function not found"
		return 1
	fi
}

# Test: stop_spinner function exists
test_stop_spinner_exists() {
	log_test "stop_spinner function exists"
	((TESTS_RUN++)) || true

	source "$PROGRESS_LIB"
	if declare -f stop_spinner >/dev/null 2>&1; then
		log_pass "stop_spinner function exists"
	else
		log_fail "stop_spinner function not found"
		return 1
	fi
}

# Test: with_spinner function exists
test_with_spinner_exists() {
	log_test "with_spinner function exists"
	((TESTS_RUN++)) || true

	source "$PROGRESS_LIB"
	if declare -f with_spinner >/dev/null 2>&1; then
		log_pass "with_spinner function exists"
	else
		log_fail "with_spinner function not found"
		return 1
	fi
}

# Test: Spinner starts and stops cleanly
test_spinner_starts_and_stops() {
	log_test "Spinner starts and stops without hanging"
	((TESTS_RUN++)) || true

	source "$PROGRESS_LIB"

	# Run in a subshell with timeout to prevent hanging
	if timeout 5 bash -c "
		source '$PROGRESS_LIB'
		start_spinner 'Testing...'
		sleep 0.2
		stop_spinner 0
	" >/dev/null 2>&1; then
		log_pass "Spinner starts and stops cleanly"
	else
		log_fail "Spinner failed or timed out"
		return 1
	fi
}

# Test: Spinner doesn't leave background processes
test_no_orphan_processes() {
	log_test "Spinner doesn't leave orphan processes"
	((TESTS_RUN++)) || true

	source "$PROGRESS_LIB"

	# Get process count before
	local before_count
	before_count=$(pgrep -f "spinner" 2>/dev/null | wc -l)

	# Run spinner in subshell
	(
		source "$PROGRESS_LIB"
		start_spinner "Testing..."
		sleep 0.1
		stop_spinner 0
	) >/dev/null 2>&1

	# Wait a moment for cleanup
	sleep 0.2

	# Get process count after
	local after_count
	after_count=$(pgrep -f "spinner" 2>/dev/null | wc -l)

	if [[ "$after_count" -le "$before_count" ]]; then
		log_pass "No orphan spinner processes"
	else
		log_fail "Found orphan spinner processes (before: $before_count, after: $after_count)"
		return 1
	fi
}

# Test: with_spinner returns correct exit code for success
test_with_spinner_success() {
	log_test "with_spinner returns correct exit code for success"
	((TESTS_RUN++)) || true

	# Run in subshell with fresh environment
	set +e
	bash -c "
		source '$PROGRESS_LIB'
		DEVBOX_NO_SPINNER=1 with_spinner 'Test' 'true'
	" >/dev/null 2>&1
	local exit_code=$?
	set -e

	if [[ $exit_code -eq 0 ]]; then
		log_pass "with_spinner returns 0 for success"
	else
		log_fail "with_spinner returned $exit_code instead of 0"
		return 1
	fi
}

# Test: with_spinner returns correct exit code for failure
test_with_spinner_failure() {
	log_test "with_spinner returns correct exit code for failure"
	((TESTS_RUN++)) || true

	# Run in subshell with fresh environment
	set +e
	bash -c "
		source '$PROGRESS_LIB'
		DEVBOX_NO_SPINNER=1 with_spinner 'Test' 'false'
	" >/dev/null 2>&1
	local exit_code=$?
	set -e

	if [[ $exit_code -ne 0 ]]; then
		log_pass "with_spinner returns non-zero for failure"
	else
		log_fail "with_spinner returned 0 for failing command"
		return 1
	fi
}

# Test: with_spinner captures command output
test_with_spinner_output() {
	log_test "with_spinner captures command output"
	((TESTS_RUN++)) || true

	# Run in subshell with fresh environment
	local output
	output=$(bash -c "
		source '$PROGRESS_LIB'
		DEVBOX_NO_SPINNER=1 with_spinner 'Test' 'echo hello world'
	" 2>&1)

	if [[ "$output" == *"hello world"* ]]; then
		log_pass "with_spinner captures command output"
	else
		log_fail "with_spinner didn't capture output: $output"
		return 1
	fi
}

# Test: is_terminal function exists
test_is_terminal_exists() {
	log_test "is_terminal function exists"
	((TESTS_RUN++)) || true

	source "$PROGRESS_LIB"
	if declare -f is_terminal >/dev/null 2>&1; then
		log_pass "is_terminal function exists"
	else
		log_fail "is_terminal function not found"
		return 1
	fi
}

# Test: Non-interactive mode falls back gracefully
test_non_interactive_fallback() {
	log_test "Non-interactive mode shows plain output"
	((TESTS_RUN++)) || true

	# Run in subshell with fresh environment
	local output
	output=$(bash -c "
		source '$PROGRESS_LIB'
		DEVBOX_NO_SPINNER=1 with_spinner 'Building' 'echo done'
	" 2>&1)

	# Should contain the message without spinner characters
	if [[ "$output" == *"Building"* ]] || [[ "$output" == *"done"* ]]; then
		log_pass "Non-interactive mode works correctly"
	else
		log_fail "Non-interactive mode output unexpected: $output"
		return 1
	fi
}

# ============================================================================
# Run all tests
# ============================================================================

echo "============================================"
echo "Running progress indicator tests"
echo "============================================"
echo

# Run tests in order (some depend on previous passing)
test_library_exists || exit 1
test_library_sources || exit 1
test_start_spinner_exists
test_stop_spinner_exists
test_with_spinner_exists
test_is_terminal_exists
test_spinner_starts_and_stops
test_no_orphan_processes
test_with_spinner_success
test_with_spinner_failure
test_with_spinner_output
test_non_interactive_fallback

# Summary
echo
echo "============================================"
echo "Test Summary"
echo "============================================"
echo "Tests run:     $TESTS_RUN"
echo "Tests passed:  $TESTS_PASSED"
echo "Tests skipped: $TESTS_SKIPPED"

TESTS_FAILED=$((TESTS_RUN - TESTS_PASSED - TESTS_SKIPPED))

if [[ $TESTS_FAILED -eq 0 ]]; then
	echo -e "${GREEN}All tests passed!${NC}"
	exit 0
else
	echo -e "${RED}$TESTS_FAILED tests failed${NC}"
	exit 1
fi
