#!/bin/bash
# Test bash completion works without bash-completion package installed

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
COMPLETION_FILE="$REPO_ROOT/completions/devbox.bash"

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log_test() {
    echo -e "${BLUE}TEST:${NC} $*"
}

log_pass() {
    echo -e "${GREEN}  ✓ PASS:${NC} $*"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}  ✗ FAIL:${NC} $*"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}  ⊘ SKIP:${NC} $*"
}

# Test that completion file can be sourced without bash-completion package
test_source_without_bash_completion() {
    log_test "Completion file can be sourced without bash-completion package"
    ((TESTS_RUN++))

    # Simulate environment without bash-completion
    if bash -c "
        # Don't load bash-completion
        unset -f _init_completion 2>/dev/null || true
        source '$COMPLETION_FILE' 2>&1
        # Check if our completion function exists
        type _devbox_completion >/dev/null 2>&1
    "; then
        log_pass "Completion file sourced successfully"
    else
        log_fail "Completion file failed to source"
        return 1
    fi
}

# Test that completion function is registered
test_completion_registered() {
    log_test "Completion function is registered for 'devbox' command"
    ((TESTS_RUN++))

    # Check if complete is registered
    if bash -c "
        source '$COMPLETION_FILE' 2>&1
        complete -p devbox 2>&1 | grep -q '_devbox_completion'
    "; then
        log_pass "Completion function registered"
    else
        log_fail "Completion function not registered"
        return 1
    fi
}

# Test basic completion (commands)
test_basic_command_completion() {
    log_test "Basic command completion works"
    ((TESTS_RUN++))

    # Simulate tab completion for "devbox " (empty)
    result=$(bash -c "
        source '$COMPLETION_FILE' 2>&1 >/dev/null
        # Simulate completion context
        COMP_WORDS=(devbox '')
        COMP_CWORD=1
        COMP_LINE='devbox '
        COMP_POINT=7
        _devbox_completion
        echo \${COMPREPLY[*]}
    " 2>&1)

    if [[ "$result" == *"init"* ]] && [[ "$result" == *"create"* ]] && [[ "$result" == *"list"* ]]; then
        log_pass "Command completion returns expected commands"
    else
        log_fail "Command completion didn't return expected commands: $result"
        return 1
    fi
}

# Main test runner
main() {
    echo "================================================"
    echo "  Devbox Bash Completion Standalone Tests"
    echo "================================================"
    echo

    # Check test file exists
    if [[ ! -f "$COMPLETION_FILE" ]]; then
        echo -e "${RED}ERROR:${NC} Completion file not found: $COMPLETION_FILE"
        exit 1
    fi

    # Run tests
    test_source_without_bash_completion || true
    test_completion_registered || true
    test_basic_command_completion || true

    # Summary
    echo
    echo "================================================"
    echo "  Test Summary"
    echo "================================================"
    echo "  Tests run:    $TESTS_RUN"
    echo -e "  Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "  Tests failed: ${RED}$TESTS_FAILED${NC}"
        exit 1
    else
        echo -e "  Tests failed: $TESTS_FAILED"
        echo
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main "$@"
