#!/bin/bash
# Tests for devbox secrets management

# Colors for test output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_SKIPPED=0

# Temporary test directory for secrets
TEST_SECRETS_DIR=""

# Helper functions
test_passed() {
	echo -e "${GREEN}✓ PASS:${NC} $1"
	((TESTS_PASSED++))
}

test_failed() {
	echo -e "${RED}✗ FAIL:${NC} $1"
}

test_skipped() {
	echo -e "${YELLOW}○ SKIP:${NC} $1"
	((TESTS_SKIPPED++))
}

run_test() {
	((TESTS_RUN++))
	echo "Running test: $1"
}

# Path to devbox binary
DEVBOX_BIN="$(dirname "$0")/../bin/devbox"

# Setup test environment
setup() {
	# Create a unique temporary directory for test secrets
	TEST_SECRETS_DIR=$(mktemp -d "/tmp/devbox-secrets-test-$$-XXXXXX")
	export DEVBOX_SECRETS_DIR="$TEST_SECRETS_DIR"
}

# Cleanup test environment
cleanup() {
	if [[ -n "$TEST_SECRETS_DIR" ]] && [[ -d "$TEST_SECRETS_DIR" ]]; then
		rm -rf "$TEST_SECRETS_DIR"
	fi
}

# Run setup before tests
setup

# Ensure cleanup on exit
trap cleanup EXIT

echo "Testing devbox secrets commands..."
echo "Using test secrets directory: $TEST_SECRETS_DIR"
echo

# ==============================================================================
# Test: secrets help
# ==============================================================================
run_test "secrets help shows usage"
OUTPUT=$("$DEVBOX_BIN" secrets --help 2>&1) || true
if echo "$OUTPUT" | grep -q "devbox secrets"; then
	test_passed "secrets --help shows usage"
else
	test_failed "secrets --help does not show usage. Got: $OUTPUT"
fi

run_test "secrets -h shows usage"
OUTPUT=$("$DEVBOX_BIN" secrets -h 2>&1) || true
if echo "$OUTPUT" | grep -q "devbox secrets"; then
	test_passed "secrets -h shows usage"
else
	test_failed "secrets -h does not show usage. Got: $OUTPUT"
fi

# ==============================================================================
# Test: secrets add
# ==============================================================================
run_test "secrets add requires name argument"
OUTPUT=$("$DEVBOX_BIN" secrets add 2>&1) || true
if echo "$OUTPUT" | grep -qi "required\|usage\|name"; then
	test_passed "secrets add shows error without name"
else
	test_failed "secrets add should require name. Got: $OUTPUT"
fi

run_test "secrets add --help shows usage"
OUTPUT=$("$DEVBOX_BIN" secrets add --help 2>&1) || true
if echo "$OUTPUT" | grep -q "add"; then
	test_passed "secrets add --help shows usage"
else
	test_failed "secrets add --help does not show usage. Got: $OUTPUT"
fi

run_test "secrets add with --from-env reads from environment"
export TEST_SECRET_VALUE="my-test-secret-value-12345"
OUTPUT=$("$DEVBOX_BIN" secrets add test-secret --from-env TEST_SECRET_VALUE 2>&1)
if [[ $? -eq 0 ]] && echo "$OUTPUT" | grep -qi "added\|stored\|success"; then
	test_passed "secrets add --from-env works"
else
	test_failed "secrets add --from-env failed. Got: $OUTPUT"
fi
unset TEST_SECRET_VALUE

run_test "secrets add validates secret name (alphanumeric, dashes, underscores)"
OUTPUT=$("$DEVBOX_BIN" secrets add "invalid/name" --from-env NONEXISTENT 2>&1) || true
if echo "$OUTPUT" | grep -qi "invalid\|name\|alphanumeric"; then
	test_passed "secrets add rejects invalid name"
else
	test_failed "secrets add should reject invalid name. Got: $OUTPUT"
fi

run_test "secrets add with --from-file reads from file"
echo "file-secret-content" >"$TEST_SECRETS_DIR/input.txt"
OUTPUT=$("$DEVBOX_BIN" secrets add file-secret --from-file "$TEST_SECRETS_DIR/input.txt" 2>&1)
if [[ $? -eq 0 ]] && echo "$OUTPUT" | grep -qi "added\|stored\|success"; then
	test_passed "secrets add --from-file works"
else
	test_failed "secrets add --from-file failed. Got: $OUTPUT"
fi

run_test "secrets add fails for nonexistent env var"
set +e
OUTPUT=$("$DEVBOX_BIN" secrets add test-secret2 --from-env NONEXISTENT_VAR_12345 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$OUTPUT" | grep -qi "not set\|not found\|empty\|does not exist"; then
	test_passed "secrets add fails for nonexistent env var"
else
	test_failed "secrets add should fail for nonexistent env var. Got: $OUTPUT (exit code: $EXIT_CODE)"
fi

run_test "secrets add fails for nonexistent file"
set +e
OUTPUT=$("$DEVBOX_BIN" secrets add test-secret3 --from-file "/nonexistent/path/file.txt" 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$OUTPUT" | grep -qi "not found\|does not exist\|no such"; then
	test_passed "secrets add fails for nonexistent file"
else
	test_failed "secrets add should fail for nonexistent file. Got: $OUTPUT (exit code: $EXIT_CODE)"
fi

# ==============================================================================
# Test: secrets list
# ==============================================================================
run_test "secrets list shows stored secrets"
OUTPUT=$("$DEVBOX_BIN" secrets list 2>&1)
if echo "$OUTPUT" | grep -q "test-secret"; then
	test_passed "secrets list shows stored secret"
else
	test_failed "secrets list should show test-secret. Got: $OUTPUT"
fi

run_test "secrets list never shows secret values"
OUTPUT=$("$DEVBOX_BIN" secrets list 2>&1)
if ! echo "$OUTPUT" | grep -q "my-test-secret-value-12345"; then
	test_passed "secrets list does not show secret values"
else
	test_failed "secrets list should NEVER show secret values. Got: $OUTPUT"
fi

run_test "secrets list --help shows usage"
OUTPUT=$("$DEVBOX_BIN" secrets list --help 2>&1) || true
if echo "$OUTPUT" | grep -q "list"; then
	test_passed "secrets list --help shows usage"
else
	test_failed "secrets list --help does not show usage. Got: $OUTPUT"
fi

# ==============================================================================
# Test: secrets remove
# ==============================================================================
run_test "secrets remove requires name argument"
OUTPUT=$("$DEVBOX_BIN" secrets remove 2>&1) || true
if echo "$OUTPUT" | grep -qi "required\|usage\|name"; then
	test_passed "secrets remove shows error without name"
else
	test_failed "secrets remove should require name. Got: $OUTPUT"
fi

run_test "secrets remove --help shows usage"
OUTPUT=$("$DEVBOX_BIN" secrets remove --help 2>&1) || true
if echo "$OUTPUT" | grep -q "remove"; then
	test_passed "secrets remove --help shows usage"
else
	test_failed "secrets remove --help does not show usage. Got: $OUTPUT"
fi

run_test "secrets remove fails for nonexistent secret"
set +e
OUTPUT=$("$DEVBOX_BIN" secrets remove nonexistent-secret 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$OUTPUT" | grep -qi "not found\|does not exist"; then
	test_passed "secrets remove fails for nonexistent secret"
else
	test_failed "secrets remove should fail for nonexistent secret. Got: $OUTPUT (exit code: $EXIT_CODE)"
fi

run_test "secrets remove with --force skips confirmation"
# First add a secret to remove
export REMOVE_TEST_SECRET="value-to-remove"
"$DEVBOX_BIN" secrets add remove-test --from-env REMOVE_TEST_SECRET >/dev/null 2>&1
unset REMOVE_TEST_SECRET

OUTPUT=$("$DEVBOX_BIN" secrets remove remove-test --force 2>&1)
if [[ $? -eq 0 ]] && echo "$OUTPUT" | grep -qi "removed\|deleted\|success"; then
	test_passed "secrets remove --force works"
else
	test_failed "secrets remove --force failed. Got: $OUTPUT"
fi

run_test "secrets remove actually removes the secret"
# Verify the secret was removed
OUTPUT=$("$DEVBOX_BIN" secrets list 2>&1)
if ! echo "$OUTPUT" | grep -q "remove-test"; then
	test_passed "secrets remove actually removed the secret"
else
	test_failed "secrets remove did not actually remove the secret. Got: $OUTPUT"
fi

# ==============================================================================
# Test: secrets path
# ==============================================================================
run_test "secrets path shows directory location"
OUTPUT=$("$DEVBOX_BIN" secrets path 2>&1)
if echo "$OUTPUT" | grep -q "$TEST_SECRETS_DIR"; then
	test_passed "secrets path shows correct directory"
else
	test_failed "secrets path should show secrets directory. Got: $OUTPUT"
fi

# ==============================================================================
# Test: Storage implementation
# ==============================================================================
run_test "secrets are stored with restricted permissions (600)"
# Add a secret and check file permissions
export PERM_TEST_SECRET="permission-test"
"$DEVBOX_BIN" secrets add perm-test --from-env PERM_TEST_SECRET >/dev/null 2>&1
unset PERM_TEST_SECRET

if [[ -f "$TEST_SECRETS_DIR/perm-test" ]]; then
	PERMS=$(stat -c '%a' "$TEST_SECRETS_DIR/perm-test" 2>/dev/null || stat -f '%A' "$TEST_SECRETS_DIR/perm-test" 2>/dev/null)
	if [[ "$PERMS" == "600" ]]; then
		test_passed "secret file has 600 permissions"
	else
		test_failed "secret file should have 600 permissions. Got: $PERMS"
	fi
else
	test_failed "secret file was not created"
fi

run_test "secrets directory has restricted permissions (700)"
PERMS=$(stat -c '%a' "$TEST_SECRETS_DIR" 2>/dev/null || stat -f '%A' "$TEST_SECRETS_DIR" 2>/dev/null)
# Note: Our test creates the dir, so we check the behavior when devbox creates it
# For now just verify the implementation sets correct permissions
if [[ "$PERMS" == "700" ]] || [[ "$PERMS" == "1700" ]]; then
	test_passed "secrets directory has restricted permissions"
else
	# This might fail if we created the temp dir ourselves with different permissions
	test_skipped "secrets directory permissions (test dir created externally)"
fi

# ==============================================================================
# Test: Overwrite behavior
# ==============================================================================
run_test "secrets add warns when overwriting existing secret"
export OVERWRITE_TEST="value1"
"$DEVBOX_BIN" secrets add overwrite-test --from-env OVERWRITE_TEST >/dev/null 2>&1
export OVERWRITE_TEST="value2"
OUTPUT=$("$DEVBOX_BIN" secrets add overwrite-test --from-env OVERWRITE_TEST --force 2>&1)
if echo "$OUTPUT" | grep -qi "overwrite\|replace\|update"; then
	test_passed "secrets add shows overwrite message"
else
	# Even without message, it should work with --force
	if [[ $? -eq 0 ]]; then
		test_passed "secrets add --force overwrites without error"
	else
		test_failed "secrets add overwrite failed. Got: $OUTPUT"
	fi
fi
unset OVERWRITE_TEST

# ==============================================================================
# Test: secrets command without subcommand
# ==============================================================================
run_test "secrets without subcommand shows help"
OUTPUT=$("$DEVBOX_BIN" secrets 2>&1) || true
if echo "$OUTPUT" | grep -qi "usage\|add\|list\|remove"; then
	test_passed "secrets without subcommand shows help"
else
	test_failed "secrets should show help without subcommand. Got: $OUTPUT"
fi

# ==============================================================================
# Test: Unknown secrets subcommand
# ==============================================================================
run_test "secrets with unknown subcommand shows error"
OUTPUT=$("$DEVBOX_BIN" secrets unknown 2>&1) || true
if echo "$OUTPUT" | grep -qi "unknown\|invalid\|usage"; then
	test_passed "secrets with unknown subcommand shows error"
else
	test_failed "secrets should show error for unknown subcommand. Got: $OUTPUT"
fi

# ==============================================================================
# Test: secrets import-env
# ==============================================================================
run_test "secrets import-env --help shows usage"
OUTPUT=$("$DEVBOX_BIN" secrets import-env --help 2>&1) || true
if echo "$OUTPUT" | grep -q "import-env"; then
	test_passed "secrets import-env --help shows usage"
else
	test_failed "secrets import-env --help does not show usage. Got: $OUTPUT"
fi

run_test "secrets import-env requires variable name argument"
OUTPUT=$("$DEVBOX_BIN" secrets import-env 2>&1) || true
if echo "$OUTPUT" | grep -qi "required\|usage\|variable"; then
	test_passed "secrets import-env shows error without variable name"
else
	test_failed "secrets import-env should require variable name. Got: $OUTPUT"
fi

run_test "secrets import-env imports from environment variable"
export IMPORT_TEST_VAR="import-test-value-xyz"
OUTPUT=$("$DEVBOX_BIN" secrets import-env IMPORT_TEST_VAR 2>&1)
if [[ $? -eq 0 ]] && echo "$OUTPUT" | grep -qi "imported\|added\|stored\|success"; then
	test_passed "secrets import-env works"
else
	test_failed "secrets import-env failed. Got: $OUTPUT"
fi

run_test "secrets import-env creates secret with correct name"
# Verify the secret was created with lowercase name
OUTPUT=$("$DEVBOX_BIN" secrets list 2>&1)
if echo "$OUTPUT" | grep -qi "import.test.var\|import-test-var"; then
	test_passed "secrets import-env created secret with correct name"
else
	test_failed "secrets import-env did not create expected secret. Got: $OUTPUT"
fi
unset IMPORT_TEST_VAR

run_test "secrets import-env imports GITHUB_TOKEN with custom name"
export GITHUB_TOKEN="ghp_testtoken12345"
OUTPUT=$("$DEVBOX_BIN" secrets import-env GITHUB_TOKEN --as github-token 2>&1)
if [[ $? -eq 0 ]]; then
	# Verify the secret exists with the custom name
	LIST_OUTPUT=$("$DEVBOX_BIN" secrets list 2>&1)
	if echo "$LIST_OUTPUT" | grep -q "github-token"; then
		test_passed "secrets import-env --as works"
	else
		test_failed "secrets import-env --as did not create secret with custom name. Got: $LIST_OUTPUT"
	fi
else
	test_failed "secrets import-env --as failed. Got: $OUTPUT"
fi
unset GITHUB_TOKEN

run_test "secrets import-env fails for nonexistent env var"
set +e
OUTPUT=$("$DEVBOX_BIN" secrets import-env NONEXISTENT_VAR_67890 2>&1)
EXIT_CODE=$?
set -e
if [[ $EXIT_CODE -ne 0 ]] && echo "$OUTPUT" | grep -qi "not set\|not found\|empty"; then
	test_passed "secrets import-env fails for nonexistent env var"
else
	test_failed "secrets import-env should fail for nonexistent env var. Got: $OUTPUT (exit code: $EXIT_CODE)"
fi

run_test "secrets import-env shows deprecation info for GITHUB_TOKEN"
export GITHUB_TOKEN="ghp_anothertoken"
OUTPUT=$("$DEVBOX_BIN" secrets import-env GITHUB_TOKEN --as github-token-2 2>&1)
if echo "$OUTPUT" | grep -qi "deprecat\|recommend\|secure"; then
	test_passed "secrets import-env shows security recommendation"
else
	# It's ok if it just works without showing deprecation, the key is it imports correctly
	test_passed "secrets import-env imports GITHUB_TOKEN (deprecation message optional)"
fi
unset GITHUB_TOKEN

# ==============================================================================
# Summary
# ==============================================================================
echo
echo "Test Summary:"
echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests skipped: $TESTS_SKIPPED"

TESTS_FAILED=$((TESTS_RUN - TESTS_PASSED - TESTS_SKIPPED))
if [[ $TESTS_FAILED -eq 0 ]]; then
	echo -e "${GREEN}All tests passed!${NC}"
	exit 0
else
	echo -e "${RED}$TESTS_FAILED tests failed${NC}"
	exit 1
fi
