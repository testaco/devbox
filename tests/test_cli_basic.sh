#!/bin/bash
# Basic CLI tests for devbox

# Colors for test output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0

# Helper functions
test_passed() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

test_failed() {
    echo -e "${RED}✗ FAIL:${NC} $1"
}

run_test() {
    ((TESTS_RUN++))
    echo "Running test: $1"
}

# Path to devbox binary
DEVBOX_BIN="$(dirname "$0")/../bin/devbox"

# Test 1: Help command works
run_test "Help command shows usage"
OUTPUT=$("$DEVBOX_BIN" help 2>&1)
if echo "$OUTPUT" | grep -q "Devbox - Manage isolated, authenticated development containers"; then
    test_passed "Help command shows correct usage"
else
    test_failed "Help command does not show expected usage"
fi

# Test 2: No arguments shows help
run_test "No arguments shows help"
OUTPUT=$("$DEVBOX_BIN" 2>&1)
if echo "$OUTPUT" | grep -q "Devbox - Manage isolated, authenticated development containers"; then
    test_passed "No arguments correctly shows help"
else
    test_failed "No arguments does not show help"
fi

# Test 3: Unknown command shows error and help
run_test "Unknown command shows error"
OUTPUT=$("$DEVBOX_BIN" invalid-command 2>&1 || true)
if echo "$OUTPUT" | grep -q "Unknown command: invalid-command"; then
    test_passed "Unknown command shows correct error message"
else
    test_failed "Unknown command does not show expected error"
fi

# Test 4: Script is executable
run_test "Script has executable permissions"
if [[ -x "$DEVBOX_BIN" ]]; then
    test_passed "Script has executable permissions"
else
    test_failed "Script is not executable"
fi

# Test 5: Script has proper shebang
run_test "Script has bash shebang"
if head -1 "$DEVBOX_BIN" | grep -q "#!/bin/bash"; then
    test_passed "Script has correct bash shebang"
else
    test_failed "Script does not have bash shebang"
fi

# Test 6: Unimplemented commands show appropriate error
run_test "Unimplemented commands show not implemented error"
OUTPUT=$("$DEVBOX_BIN" attach 2>&1 || true)
if echo "$OUTPUT" | grep -q "not yet implemented"; then
    test_passed "Unimplemented commands show appropriate error"
else
    test_failed "Unimplemented commands do not show expected error"
fi

# Summary
echo
echo "Test Summary:"
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"

if [[ $TESTS_PASSED -eq $TESTS_RUN ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    TESTS_FAILED=$((TESTS_RUN - TESTS_PASSED))
    echo -e "${RED}$TESTS_FAILED tests failed${NC}"
    exit 1
fi