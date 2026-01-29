#!/bin/bash
# Test suite for install.sh script

set -o pipefail

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_SCRIPT="$PROJECT_ROOT/install.sh"

# Test tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_test() {
	echo -e "${YELLOW}TEST:${NC} $*"
}

log_pass() {
	echo -e "${GREEN}PASS:${NC} $*"
	((TESTS_PASSED++))
}

log_fail() {
	echo -e "${RED}FAIL:${NC} $*"
	((TESTS_FAILED++))
}

# ============================================================================
# Test: Install script exists and is executable
# ============================================================================
test_install_script_exists() {
	log_test "Install script exists and is executable"
	((TESTS_RUN++))

	if [[ ! -f "$INSTALL_SCRIPT" ]]; then
		log_fail "Install script not found at $INSTALL_SCRIPT"
		return 1
	fi

	if [[ ! -x "$INSTALL_SCRIPT" ]]; then
		log_fail "Install script is not executable"
		return 1
	fi

	log_pass "Install script exists and is executable"
}

# ============================================================================
# Test: Help flag shows usage
# ============================================================================
test_help_flag() {
	log_test "Help flag shows usage"
	((TESTS_RUN++))

	local output
	output=$("$INSTALL_SCRIPT" --help 2>&1) || true

	if [[ "$output" != *"Usage"* ]] && [[ "$output" != *"USAGE"* ]]; then
		log_fail "Help output should contain 'Usage'"
		echo "Output: $output"
		return 1
	fi

	if [[ "$output" != *"devbox"* ]]; then
		log_fail "Help output should mention 'devbox'"
		echo "Output: $output"
		return 1
	fi

	log_pass "Help flag shows usage"
}

# ============================================================================
# Test: Short help flag -h works
# ============================================================================
test_short_help_flag() {
	log_test "Short help flag -h works"
	((TESTS_RUN++))

	local output
	output=$("$INSTALL_SCRIPT" -h 2>&1) || true

	if [[ "$output" != *"Usage"* ]] && [[ "$output" != *"USAGE"* ]]; then
		log_fail "Short help output should contain 'Usage'"
		echo "Output: $output"
		return 1
	fi

	log_pass "Short help flag -h works"
}

# ============================================================================
# Test: Dry run option is available
# ============================================================================
test_dry_run_option() {
	log_test "Dry run option shows what would be done"
	((TESTS_RUN++))

	local output
	output=$("$INSTALL_SCRIPT" --dry-run 2>&1) || true

	if [[ "$output" != *"Would"* ]] && [[ "$output" != *"DRY RUN"* ]] && [[ "$output" != *"dry-run"* ]] && [[ "$output" != *"Dry run"* ]]; then
		log_fail "Dry run output should indicate what would be done"
		echo "Output: $output"
		return 1
	fi

	log_pass "Dry run option shows what would be done"
}

# ============================================================================
# Test: Uninstall option is available
# ============================================================================
test_uninstall_option() {
	log_test "Uninstall option is available"
	((TESTS_RUN++))

	local output
	output=$("$INSTALL_SCRIPT" --help 2>&1) || true

	if [[ "$output" != *"uninstall"* ]] && [[ "$output" != *"remove"* ]]; then
		log_fail "Help should mention uninstall option"
		echo "Output: $output"
		return 1
	fi

	log_pass "Uninstall option is available"
}

# ============================================================================
# Test: Prefix option is available
# ============================================================================
test_prefix_option() {
	log_test "Prefix option is available"
	((TESTS_RUN++))

	local output
	output=$("$INSTALL_SCRIPT" --help 2>&1) || true

	if [[ "$output" != *"prefix"* ]] && [[ "$output" != *"PREFIX"* ]]; then
		log_fail "Help should mention prefix option"
		echo "Output: $output"
		return 1
	fi

	log_pass "Prefix option is available"
}

# ============================================================================
# Test: Custom prefix with dry-run
# ============================================================================
test_custom_prefix_dry_run() {
	log_test "Custom prefix with dry-run works"
	((TESTS_RUN++))

	local test_prefix="/tmp/devbox-test-install"
	local output
	output=$("$INSTALL_SCRIPT" --prefix "$test_prefix" --dry-run 2>&1) || true

	if [[ "$output" != *"$test_prefix"* ]]; then
		log_fail "Dry run should show custom prefix path"
		echo "Output: $output"
		return 1
	fi

	log_pass "Custom prefix with dry-run works"
}

# ============================================================================
# Test: Skip-image option is available
# ============================================================================
test_skip_image_option() {
	log_test "Skip-image option is available"
	((TESTS_RUN++))

	local output
	output=$("$INSTALL_SCRIPT" --help 2>&1) || true

	if [[ "$output" != *"skip-image"* ]] && [[ "$output" != *"image"* ]]; then
		log_fail "Help should mention skip-image option"
		echo "Output: $output"
		return 1
	fi

	log_pass "Skip-image option is available"
}

# ============================================================================
# Test: Skip-completion option is available
# ============================================================================
test_skip_completion_option() {
	log_test "Skip-completion option is available"
	((TESTS_RUN++))

	local output
	output=$("$INSTALL_SCRIPT" --help 2>&1) || true

	if [[ "$output" != *"skip-completion"* ]] && [[ "$output" != *"completion"* ]]; then
		log_fail "Help should mention skip-completion option"
		echo "Output: $output"
		return 1
	fi

	log_pass "Skip-completion option is available"
}

# ============================================================================
# Test: Actual install to temp directory
# ============================================================================
test_install_to_temp_dir() {
	log_test "Install to temp directory works"
	((TESTS_RUN++))

	local test_prefix="/tmp/devbox-install-test-$$"

	# Cleanup from any previous runs
	rm -rf "$test_prefix" 2>/dev/null || true

	local output
	if ! output=$("$INSTALL_SCRIPT" --prefix "$test_prefix" --skip-image --skip-completion 2>&1); then
		log_fail "Install command failed"
		echo "Output: $output"
		rm -rf "$test_prefix" 2>/dev/null || true
		return 1
	fi

	# Check that devbox binary was installed
	if [[ ! -f "$test_prefix/bin/devbox" ]]; then
		log_fail "devbox binary was not installed to $test_prefix/bin/devbox"
		echo "Contents: $(ls -la "$test_prefix" 2>&1)"
		rm -rf "$test_prefix" 2>/dev/null || true
		return 1
	fi

	# Check that the installed binary is executable
	if [[ ! -x "$test_prefix/bin/devbox" ]]; then
		log_fail "Installed devbox binary is not executable"
		rm -rf "$test_prefix" 2>/dev/null || true
		return 1
	fi

	# Check that the installed binary shows help
	if ! "$test_prefix/bin/devbox" --help >/dev/null 2>&1; then
		log_fail "Installed devbox binary does not work"
		rm -rf "$test_prefix" 2>/dev/null || true
		return 1
	fi

	# Cleanup
	rm -rf "$test_prefix"

	log_pass "Install to temp directory works"
}

# ============================================================================
# Test: Uninstall from temp directory
# ============================================================================
test_uninstall_from_temp_dir() {
	log_test "Uninstall from temp directory works"
	((TESTS_RUN++))

	local test_prefix="/tmp/devbox-uninstall-test-$$"

	# Cleanup from any previous runs
	rm -rf "$test_prefix" 2>/dev/null || true

	# First install
	if ! "$INSTALL_SCRIPT" --prefix "$test_prefix" --skip-image --skip-completion >/dev/null 2>&1; then
		log_fail "Install failed, cannot test uninstall"
		rm -rf "$test_prefix" 2>/dev/null || true
		return 1
	fi

	# Verify install worked
	if [[ ! -f "$test_prefix/bin/devbox" ]]; then
		log_fail "Install did not create devbox binary"
		rm -rf "$test_prefix" 2>/dev/null || true
		return 1
	fi

	# Now uninstall
	local output
	if ! output=$("$INSTALL_SCRIPT" --prefix "$test_prefix" --uninstall 2>&1); then
		log_fail "Uninstall command failed"
		echo "Output: $output"
		rm -rf "$test_prefix" 2>/dev/null || true
		return 1
	fi

	# Verify devbox binary is gone
	if [[ -f "$test_prefix/bin/devbox" ]]; then
		log_fail "devbox binary still exists after uninstall"
		rm -rf "$test_prefix" 2>/dev/null || true
		return 1
	fi

	# Cleanup
	rm -rf "$test_prefix"

	log_pass "Uninstall from temp directory works"
}

# ============================================================================
# Test: Completion installation
# ============================================================================
test_completion_installation() {
	log_test "Completion file is installed with --prefix"
	((TESTS_RUN++))

	local test_prefix="/tmp/devbox-completion-test-$$"

	# Cleanup from any previous runs
	rm -rf "$test_prefix" 2>/dev/null || true

	# Install with completion
	if ! "$INSTALL_SCRIPT" --prefix "$test_prefix" --skip-image 2>&1; then
		log_fail "Install command failed"
		rm -rf "$test_prefix" 2>/dev/null || true
		return 1
	fi

	# Check that completion file was installed
	local completion_found=false
	if [[ -f "$test_prefix/share/bash-completion/completions/devbox" ]] ||
		[[ -f "$test_prefix/etc/bash_completion.d/devbox" ]] ||
		[[ -f "$test_prefix/share/bash-completion/devbox.bash" ]]; then
		completion_found=true
	fi

	if [[ "$completion_found" != "true" ]]; then
		log_fail "Completion file was not installed"
		echo "Contents: $(find "$test_prefix" -type f 2>&1)"
		rm -rf "$test_prefix" 2>/dev/null || true
		return 1
	fi

	# Cleanup
	rm -rf "$test_prefix"

	log_pass "Completion file is installed with --prefix"
}

# ============================================================================
# Test: Unknown option shows error
# ============================================================================
test_unknown_option() {
	log_test "Unknown option shows error"
	((TESTS_RUN++))

	local output
	output=$("$INSTALL_SCRIPT" --unknown-option 2>&1) || true
	local exit_code=$?

	# Should fail or show error message
	if [[ $exit_code -eq 0 ]] && [[ "$output" != *"Unknown"* ]] && [[ "$output" != *"unknown"* ]] && [[ "$output" != *"Invalid"* ]] && [[ "$output" != *"invalid"* ]]; then
		log_fail "Unknown option should show error or fail"
		echo "Output: $output"
		return 1
	fi

	log_pass "Unknown option shows error"
}

# ============================================================================
# Main test runner
# ============================================================================
main() {
	echo "============================================"
	echo "Devbox Install Script Test Suite"
	echo "============================================"
	echo

	# Check if install script exists before running tests
	if [[ ! -f "$INSTALL_SCRIPT" ]]; then
		echo -e "${RED}ERROR:${NC} Install script not found at $INSTALL_SCRIPT"
		echo "Tests cannot run without the install script."
		exit 1
	fi

	# Run tests
	test_install_script_exists
	test_help_flag
	test_short_help_flag
	test_dry_run_option
	test_uninstall_option
	test_prefix_option
	test_custom_prefix_dry_run
	test_skip_image_option
	test_skip_completion_option
	test_install_to_temp_dir
	test_uninstall_from_temp_dir
	test_completion_installation
	test_unknown_option

	echo
	echo "============================================"
	echo "Test Results"
	echo "============================================"
	echo "Tests run:    $TESTS_RUN"
	echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
	echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
	echo

	if [[ $TESTS_FAILED -gt 0 ]]; then
		echo -e "${RED}Some tests failed!${NC}"
		exit 1
	else
		echo -e "${GREEN}All tests passed!${NC}"
		exit 0
	fi
}

main "$@"
