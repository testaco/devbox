#!/bin/bash
# Test suite for devbox network egress control
# Tests flag parsing, profile loading, and basic egress functionality

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEVBOX_BIN="$PROJECT_ROOT/bin/devbox"

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test result logging
log_test() {
	echo -e "${YELLOW}TEST:${NC} $*"
}

log_pass() {
	echo -e "${GREEN}PASS:${NC} $*"
	((TESTS_PASSED++)) || true
}

log_fail() {
	echo -e "${RED}FAIL:${NC} $*"
	((TESTS_FAILED++)) || true
}

log_skip() {
	echo -e "${YELLOW}SKIP:${NC} $*"
	((TESTS_SKIPPED++)) || true
}

# Setup test environment
setup() {
	# Create temporary secrets directory for tests
	export DEVBOX_SECRETS_DIR=$(mktemp -d)

	# Create test secrets
	mkdir -p "$DEVBOX_SECRETS_DIR"
	echo "test_github_token" >"$DEVBOX_SECRETS_DIR/test-github-secret"
	echo "test_claude_token" >"$DEVBOX_SECRETS_DIR/test-claude-secret"
	chmod 600 "$DEVBOX_SECRETS_DIR/test-github-secret"
	chmod 600 "$DEVBOX_SECRETS_DIR/test-claude-secret"
}

# Cleanup test environment
cleanup() {
	if [[ -n "${DEVBOX_SECRETS_DIR:-}" ]]; then
		rm -rf "$DEVBOX_SECRETS_DIR"
	fi
}

trap cleanup EXIT

# ============================================================================
# Test: --egress flag parsing
# ============================================================================

test_egress_flag_help() {
	log_test "Testing --egress flag appears in help"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create --help 2>&1); then
		if [[ "$output" == *"--egress"* ]]; then
			log_pass "--egress flag appears in help"
		else
			log_fail "--egress flag not found in help output"
			return 1
		fi
	else
		log_fail "Help command failed"
		return 1
	fi
}

test_egress_flag_values_in_help() {
	log_test "Testing egress profile values in help"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create --help 2>&1); then
		local all_found=true
		for profile in permissive standard strict airgapped; do
			if [[ "$output" != *"$profile"* ]]; then
				log_fail "Profile '$profile' not found in help"
				all_found=false
			fi
		done
		if [[ "$all_found" == true ]]; then
			log_pass "All egress profiles appear in help"
		fi
	else
		log_fail "Help command failed"
		return 1
	fi
}

test_egress_flag_parsing_permissive() {
	log_test "Testing --egress permissive flag parsing (dry-run)"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--egress permissive \
		--dry-run 2>&1); then
		if [[ "$output" == *"Egress profile: permissive"* ]]; then
			log_pass "--egress permissive parsed correctly"
		else
			log_fail "Egress profile not shown in dry-run output"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

test_egress_flag_parsing_standard() {
	log_test "Testing --egress standard flag parsing (dry-run)"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--egress standard \
		--dry-run 2>&1); then
		if [[ "$output" == *"Egress profile: standard"* ]]; then
			log_pass "--egress standard parsed correctly"
		else
			log_fail "Egress profile not shown in dry-run output"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

test_egress_flag_parsing_strict() {
	log_test "Testing --egress strict flag parsing (dry-run)"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--egress strict \
		--dry-run 2>&1); then
		if [[ "$output" == *"Egress profile: strict"* ]]; then
			log_pass "--egress strict parsed correctly"
		else
			log_fail "Egress profile not shown in dry-run output"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

test_egress_flag_parsing_airgapped() {
	log_test "Testing --egress airgapped flag parsing (dry-run)"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--egress airgapped \
		--dry-run 2>&1); then
		if [[ "$output" == *"Egress profile: airgapped"* ]]; then
			log_pass "--egress airgapped parsed correctly"
		else
			log_fail "Egress profile not shown in dry-run output"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

test_egress_invalid_profile() {
	log_test "Testing --egress with invalid profile"
	((TESTS_RUN++)) || true

	set +e
	local output
	output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--egress invalid \
		--dry-run 2>&1)
	local exit_code=$?
	set -e

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"Invalid egress profile"* ]]; then
		log_pass "Invalid egress profile rejected with error"
	else
		log_fail "Invalid profile should be rejected (exit=$exit_code)"
		echo "Output: $output"
		return 1
	fi
}

test_egress_default_profile() {
	log_test "Testing default egress profile is 'standard'"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--dry-run 2>&1); then
		if [[ "$output" == *"Egress profile: standard"* ]]; then
			log_pass "Default egress profile is 'standard'"
		else
			log_fail "Default egress profile not 'standard'"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

# ============================================================================
# Test: --allow-domain flag
# ============================================================================

test_allow_domain_flag_help() {
	log_test "Testing --allow-domain flag appears in help"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create --help 2>&1); then
		if [[ "$output" == *"--allow-domain"* ]]; then
			log_pass "--allow-domain flag appears in help"
		else
			log_fail "--allow-domain flag not found in help"
			return 1
		fi
	else
		log_fail "Help command failed"
		return 1
	fi
}

test_allow_domain_single() {
	log_test "Testing --allow-domain single domain (dry-run)"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--allow-domain example.com \
		--dry-run 2>&1); then
		if [[ "$output" == *"example.com"* ]]; then
			log_pass "--allow-domain parsed correctly"
		else
			log_fail "Allowed domain not shown in dry-run output"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

test_allow_domain_multiple() {
	log_test "Testing --allow-domain multiple domains (dry-run)"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--allow-domain example.com \
		--allow-domain api.example.com \
		--dry-run 2>&1); then
		if [[ "$output" == *"example.com"* ]] && [[ "$output" == *"api.example.com"* ]]; then
			log_pass "Multiple --allow-domain flags parsed correctly"
		else
			log_fail "Not all allowed domains shown in dry-run output"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

# ============================================================================
# Test: --block-domain flag
# ============================================================================

test_block_domain_flag_help() {
	log_test "Testing --block-domain flag appears in help"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create --help 2>&1); then
		if [[ "$output" == *"--block-domain"* ]]; then
			log_pass "--block-domain flag appears in help"
		else
			log_fail "--block-domain flag not found in help"
			return 1
		fi
	else
		log_fail "Help command failed"
		return 1
	fi
}

test_block_domain_single() {
	log_test "Testing --block-domain single domain (dry-run)"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--block-domain evil.com \
		--dry-run 2>&1); then
		if [[ "$output" == *"evil.com"* ]]; then
			log_pass "--block-domain parsed correctly"
		else
			log_fail "Blocked domain not shown in dry-run output"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

# ============================================================================
# Test: --allow-ip flag
# ============================================================================

test_allow_ip_flag_help() {
	log_test "Testing --allow-ip flag appears in help"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create --help 2>&1); then
		if [[ "$output" == *"--allow-ip"* ]]; then
			log_pass "--allow-ip flag appears in help"
		else
			log_fail "--allow-ip flag not found in help"
			return 1
		fi
	else
		log_fail "Help command failed"
		return 1
	fi
}

test_allow_ip_single() {
	log_test "Testing --allow-ip single IP (dry-run)"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--allow-ip 10.0.0.0/8 \
		--dry-run 2>&1); then
		if [[ "$output" == *"10.0.0.0/8"* ]]; then
			log_pass "--allow-ip parsed correctly"
		else
			log_fail "Allowed IP not shown in dry-run output"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

# ============================================================================
# Test: --block-ip flag
# ============================================================================

test_block_ip_flag_help() {
	log_test "Testing --block-ip flag appears in help"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create --help 2>&1); then
		if [[ "$output" == *"--block-ip"* ]]; then
			log_pass "--block-ip flag appears in help"
		else
			log_fail "--block-ip flag not found in help"
			return 1
		fi
	else
		log_fail "Help command failed"
		return 1
	fi
}

# ============================================================================
# Test: --allow-port flag
# ============================================================================

test_allow_port_flag_help() {
	log_test "Testing --allow-port flag appears in help"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create --help 2>&1); then
		if [[ "$output" == *"--allow-port"* ]]; then
			log_pass "--allow-port flag appears in help"
		else
			log_fail "--allow-port flag not found in help"
			return 1
		fi
	else
		log_fail "Help command failed"
		return 1
	fi
}

test_allow_port_single() {
	log_test "Testing --allow-port single port (dry-run)"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--allow-port 8443 \
		--dry-run 2>&1); then
		if [[ "$output" == *"8443"* ]]; then
			log_pass "--allow-port parsed correctly"
		else
			log_fail "Allowed port not shown in dry-run output"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

# ============================================================================
# Test: devbox network subcommand
# ============================================================================

test_network_subcommand_exists() {
	log_test "Testing 'devbox network' subcommand exists"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" network --help 2>&1); then
		if [[ "$output" == *"show"* ]] && [[ "$output" == *"allow"* ]] && [[ "$output" == *"block"* ]]; then
			log_pass "'devbox network' subcommand exists with subcommands"
		else
			log_fail "'devbox network' missing expected subcommands"
			echo "Output: $output"
			return 1
		fi
	else
		# Command may fail but should still show help
		if [[ "$output" == *"show"* ]]; then
			log_pass "'devbox network' subcommand exists"
		else
			log_fail "'devbox network' subcommand not found"
			echo "Output: $output"
			return 1
		fi
	fi
}

test_network_show_help() {
	log_test "Testing 'devbox network show --help'"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" network show --help 2>&1); then
		if [[ "$output" == *"container"* ]]; then
			log_pass "'devbox network show' help available"
		else
			log_fail "'devbox network show' help incomplete"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "'devbox network show --help' failed"
		echo "Output: $output"
		return 1
	fi
}

test_network_logs_help() {
	log_test "Testing 'devbox network logs --help'"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" network logs --help 2>&1); then
		if [[ "$output" == *"--blocked-only"* ]]; then
			log_pass "'devbox network logs' help shows --blocked-only"
		else
			log_fail "'devbox network logs' help missing --blocked-only"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "'devbox network logs --help' failed"
		echo "Output: $output"
		return 1
	fi
}

# ============================================================================
# Test: devbox list egress column
# ============================================================================

test_list_shows_egress_column() {
	log_test "Testing 'devbox list' shows EGRESS column"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" list 2>&1); then
		if [[ "$output" == *"EGRESS"* ]]; then
			log_pass "'devbox list' shows EGRESS column"
		else
			log_fail "'devbox list' missing EGRESS column"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "'devbox list' command failed"
		echo "Output: $output"
		return 1
	fi
}

# ============================================================================
# Test: Profile configuration files
# ============================================================================

test_profiles_directory_exists() {
	log_test "Testing profiles directory exists"
	((TESTS_RUN++)) || true

	if [[ -d "$PROJECT_ROOT/profiles" ]]; then
		log_pass "Profiles directory exists"
	else
		log_fail "Profiles directory not found at $PROJECT_ROOT/profiles"
		return 1
	fi
}

test_permissive_profile_exists() {
	log_test "Testing permissive.conf profile exists"
	((TESTS_RUN++)) || true

	if [[ -f "$PROJECT_ROOT/profiles/permissive.conf" ]]; then
		log_pass "permissive.conf profile exists"
	else
		log_fail "permissive.conf not found"
		return 1
	fi
}

test_standard_profile_exists() {
	log_test "Testing standard.conf profile exists"
	((TESTS_RUN++)) || true

	if [[ -f "$PROJECT_ROOT/profiles/standard.conf" ]]; then
		log_pass "standard.conf profile exists"
	else
		log_fail "standard.conf not found"
		return 1
	fi
}

test_strict_profile_exists() {
	log_test "Testing strict.conf profile exists"
	((TESTS_RUN++)) || true

	if [[ -f "$PROJECT_ROOT/profiles/strict.conf" ]]; then
		log_pass "strict.conf profile exists"
	else
		log_fail "strict.conf not found"
		return 1
	fi
}

test_airgapped_profile_exists() {
	log_test "Testing airgapped.conf profile exists"
	((TESTS_RUN++)) || true

	if [[ -f "$PROJECT_ROOT/profiles/airgapped.conf" ]]; then
		log_pass "airgapped.conf profile exists"
	else
		log_fail "airgapped.conf not found"
		return 1
	fi
}

test_standard_profile_has_allowed_domains() {
	log_test "Testing standard profile has allowed domains"
	((TESTS_RUN++)) || true

	if [[ -f "$PROJECT_ROOT/profiles/standard.conf" ]]; then
		local content
		content=$(cat "$PROJECT_ROOT/profiles/standard.conf")
		if [[ "$content" == *"github.com"* ]] && [[ "$content" == *"npmjs.org"* ]]; then
			log_pass "Standard profile includes expected domains"
		else
			log_fail "Standard profile missing expected domains"
			return 1
		fi
	else
		log_fail "standard.conf not found"
		return 1
	fi
}

# ============================================================================
# Test: lib/network.sh helper library
# ============================================================================

test_network_lib_exists() {
	log_test "Testing lib/network.sh exists"
	((TESTS_RUN++)) || true

	if [[ -f "$PROJECT_ROOT/lib/network.sh" ]]; then
		log_pass "lib/network.sh exists"
	else
		log_fail "lib/network.sh not found"
		return 1
	fi
}

test_network_lib_has_required_functions() {
	log_test "Testing lib/network.sh has required functions"
	((TESTS_RUN++)) || true

	if [[ -f "$PROJECT_ROOT/lib/network.sh" ]]; then
		local content
		content=$(cat "$PROJECT_ROOT/lib/network.sh")
		local all_found=true

		for func in load_egress_profile create_container_network cleanup_network_resources; do
			if [[ "$content" != *"$func()"* ]]; then
				log_fail "Function $func() not found in lib/network.sh"
				all_found=false
			fi
		done

		if [[ "$all_found" == true ]]; then
			log_pass "lib/network.sh has all required functions"
		fi
	else
		log_fail "lib/network.sh not found"
		return 1
	fi
}

# ============================================================================
# Main test runner
# ============================================================================

main() {
	echo "========================================"
	echo "Devbox Network Egress Tests"
	echo "========================================"
	echo

	# Setup
	setup

	# Run tests

	# Flag parsing tests
	test_egress_flag_help || true
	test_egress_flag_values_in_help || true
	test_egress_flag_parsing_permissive || true
	test_egress_flag_parsing_standard || true
	test_egress_flag_parsing_strict || true
	test_egress_flag_parsing_airgapped || true
	test_egress_invalid_profile || true
	test_egress_default_profile || true

	# Domain filtering flags
	test_allow_domain_flag_help || true
	test_allow_domain_single || true
	test_allow_domain_multiple || true
	test_block_domain_flag_help || true
	test_block_domain_single || true

	# IP filtering flags
	test_allow_ip_flag_help || true
	test_allow_ip_single || true
	test_block_ip_flag_help || true

	# Port filtering flags
	test_allow_port_flag_help || true
	test_allow_port_single || true

	# Network subcommand tests
	test_network_subcommand_exists || true
	test_network_show_help || true
	test_network_logs_help || true

	# List command tests
	test_list_shows_egress_column || true

	# Profile configuration tests
	test_profiles_directory_exists || true
	test_permissive_profile_exists || true
	test_standard_profile_exists || true
	test_strict_profile_exists || true
	test_airgapped_profile_exists || true
	test_standard_profile_has_allowed_domains || true

	# Library tests
	test_network_lib_exists || true
	test_network_lib_has_required_functions || true

	# Summary
	echo
	echo "========================================"
	echo "Test Summary"
	echo "========================================"
	echo "Tests run:    $TESTS_RUN"
	echo "Tests passed: $TESTS_PASSED"
	echo "Tests failed: $TESTS_FAILED"
	echo "Tests skipped: $TESTS_SKIPPED"
	echo

	if [[ $TESTS_FAILED -gt 0 ]]; then
		echo -e "${RED}FAILED${NC}: $TESTS_FAILED test(s) failed"
		exit 1
	else
		echo -e "${GREEN}PASSED${NC}: All tests passed!"
		exit 0
	fi
}

main "$@"
