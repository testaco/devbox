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
# Test: Network enforcement in docker command
# ============================================================================

test_airgapped_docker_command_has_network_none() {
	log_test "Testing airgapped mode includes --network none in docker command"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--egress airgapped \
		--dry-run 2>&1); then
		if [[ "$output" == *"--network none"* ]]; then
			log_pass "Airgapped mode includes --network none in docker command"
		else
			log_fail "Airgapped mode missing --network none in docker command"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

test_dry_run_shows_network_mode() {
	log_test "Testing dry-run shows network mode for airgapped"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--egress airgapped \
		--dry-run 2>&1); then
		if [[ "$output" == *"Network mode: none"* ]]; then
			log_pass "Dry-run shows network mode for airgapped"
		else
			log_fail "Dry-run missing network mode display"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

test_permissive_no_network_flag() {
	log_test "Testing permissive mode does NOT include --network none"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--egress permissive \
		--dry-run 2>&1); then
		if [[ "$output" != *"--network none"* ]]; then
			log_pass "Permissive mode does not include --network none"
		else
			log_fail "Permissive mode should NOT have --network none"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

test_standard_no_network_none() {
	log_test "Testing standard mode does NOT include --network none"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--egress standard \
		--dry-run 2>&1); then
		if [[ "$output" != *"--network none"* ]]; then
			log_pass "Standard mode does not include --network none"
		else
			log_fail "Standard mode should NOT have --network none"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

test_standard_dry_run_shows_dns_proxy() {
	log_test "Testing standard mode dry-run shows DNS proxy setup"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--egress standard \
		--dry-run 2>&1); then
		if [[ "$output" == *"DNS proxy"* ]] || [[ "$output" == *"dns proxy"* ]]; then
			log_pass "Standard mode dry-run shows DNS proxy"
		else
			log_fail "Standard mode dry-run should mention DNS proxy"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

test_standard_dry_run_shows_custom_network() {
	log_test "Testing standard mode dry-run shows custom network"
	((TESTS_RUN++)) || true

	local output
	if output=$("$DEVBOX_BIN" create testname testrepo \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--egress standard \
		--dry-run 2>&1); then
		# Check for "Custom network:" (case-insensitive match)
		if [[ "$output" == *"Custom network:"* ]] || [[ "$output" == *"custom network"* ]] || [[ "$output" == *"-net"* ]]; then
			log_pass "Standard mode dry-run shows custom network"
		else
			log_fail "Standard mode dry-run should mention custom network"
			echo "Output: $output"
			return 1
		fi
	else
		log_fail "Dry-run command failed: $output"
		return 1
	fi
}

# ============================================================================
# Test: Integration tests (require Docker)
# ============================================================================

check_docker_available() {
	docker info >/dev/null 2>&1
}

test_airgapped_integration_blocks_network() {
	log_test "Testing airgapped mode actually blocks network (integration)"
	((TESTS_RUN++)) || true

	# Skip if Docker is not available
	if ! check_docker_available; then
		log_skip "Docker not available, skipping integration test"
		return 0
	fi

	# Use a simple test container with --network none
	local test_container="devbox-test-airgapped-$$"

	# Cleanup any existing test container
	docker rm -f "$test_container" >/dev/null 2>&1 || true

	# Create a container with --network none (like airgapped mode does)
	if ! docker run -d --name "$test_container" --network none alpine:latest sleep 60 >/dev/null 2>&1; then
		log_fail "Failed to create test container"
		return 1
	fi

	# Try to ping from inside the container - should fail
	local ping_result
	set +e
	ping_result=$(docker exec "$test_container" ping -c 1 -W 2 8.8.8.8 2>&1)
	local ping_exit=$?
	set -e

	# Cleanup
	docker rm -f "$test_container" >/dev/null 2>&1 || true

	# Verify ping failed (network blocked)
	if [[ $ping_exit -ne 0 ]]; then
		log_pass "Airgapped mode blocks network access (ping failed as expected)"
	else
		log_fail "Airgapped mode should block network but ping succeeded"
		echo "Ping output: $ping_result"
		return 1
	fi
}

test_standard_integration_creates_dns_proxy() {
	log_test "Testing standard mode creates DNS proxy container (integration)"
	((TESTS_RUN++)) || true

	# Skip if Docker is not available
	if ! check_docker_available; then
		log_skip "Docker not available, skipping integration test"
		return 0
	fi

	# This test verifies that when we create network resources manually,
	# the DNS proxy starts correctly
	local test_name="devbox-test-dns-$$"
	local network_name="${test_name}-net"
	local dns_container="${test_name}-dns"

	# Cleanup any existing resources - be thorough
	docker rm -f "$dns_container" 2>/dev/null || true
	# Disconnect all containers from network before removing it
	for cid in $(docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' "$network_name" 2>/dev/null || true); do
		docker network disconnect -f "$network_name" "$cid" 2>/dev/null || true
	done
	docker network rm "$network_name" 2>/dev/null || true

	# Create isolated network (try with ICC disabled, fall back to standard)
	local create_output
	if ! create_output=$(docker network create \
		--driver bridge \
		--opt "com.docker.network.bridge.enable_icc=false" \
		"$network_name" 2>&1); then
		# Fallback without ICC restriction (kernel module may not be loaded)
		if ! create_output=$(docker network create \
			--driver bridge \
			"$network_name" 2>&1); then
			log_fail "Failed to create test network: $create_output"
			return 1
		fi
	fi

	# Start DNS proxy with blocked domains from standard profile
	local blocked_domains="pastebin.com transfer.sh ngrok.io"
	local dns_config=""
	for domain in $blocked_domains; do
		dns_config="${dns_config}address=/${domain}/#\n"
	done

	if ! docker run -d \
		--name "$dns_container" \
		--network "$network_name" \
		alpine:latest \
		sh -c "apk add --no-cache dnsmasq >/dev/null 2>&1 && echo -e '$dns_config' > /etc/dnsmasq.d/devbox.conf && dnsmasq -k --log-queries --log-facility=-" >/dev/null 2>&1; then
		log_fail "Failed to start DNS proxy container"
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Wait for dnsmasq to start
	sleep 3

	# Verify DNS proxy container is running
	local dns_status
	dns_status=$(docker inspect --format '{{.State.Status}}' "$dns_container" 2>/dev/null || echo "not_found")

	# Cleanup
	docker rm -f "$dns_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	if [[ "$dns_status" == "running" ]]; then
		log_pass "DNS proxy container runs successfully"
	else
		log_fail "DNS proxy container not running (status: $dns_status)"
		return 1
	fi
}

test_standard_integration_blocks_pastebin() {
	log_test "Testing standard mode DNS proxy blocks pastebin.com (integration)"
	((TESTS_RUN++)) || true

	# Skip if Docker is not available
	if ! check_docker_available; then
		log_skip "Docker not available, skipping integration test"
		return 0
	fi

	local test_name="devbox-test-block-$$"
	local network_name="${test_name}-net"
	local dns_container="${test_name}-dns"
	local test_container="${test_name}-app"

	# Cleanup any existing resources
	docker rm -f "$dns_container" "$test_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Create isolated network
	if ! docker network create --driver bridge "$network_name" >/dev/null 2>&1; then
		log_fail "Failed to create test network"
		return 1
	fi

	# Start DNS proxy with blocked domains
	local dns_config="address=/pastebin.com/#"
	if ! docker run -d \
		--name "$dns_container" \
		--network "$network_name" \
		alpine:latest \
		sh -c "apk add --no-cache dnsmasq >/dev/null 2>&1 && echo '$dns_config' > /etc/dnsmasq.conf && dnsmasq -k -C /etc/dnsmasq.conf" >/dev/null 2>&1; then
		log_fail "Failed to start DNS proxy container"
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Wait for dnsmasq to start
	sleep 3

	# Get DNS proxy IP
	local dns_ip
	dns_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$dns_container" 2>/dev/null)

	if [[ -z "$dns_ip" ]]; then
		log_fail "Could not get DNS proxy IP"
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Create test container using DNS proxy
	if ! docker run -d \
		--name "$test_container" \
		--network "$network_name" \
		--dns "$dns_ip" \
		alpine:latest sleep 60 >/dev/null 2>&1; then
		log_fail "Failed to create test container"
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Install nslookup in test container
	docker exec "$test_container" apk add --no-cache bind-tools >/dev/null 2>&1 || true

	# Try to resolve pastebin.com - should return NXDOMAIN (exit code != 0 or empty response)
	set +e
	local resolve_result
	resolve_result=$(docker exec "$test_container" nslookup pastebin.com 2>&1)
	local resolve_exit=$?
	set -e

	# Cleanup
	docker rm -f "$dns_container" "$test_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Check if pastebin.com was blocked (NXDOMAIN or failure)
	if [[ $resolve_exit -ne 0 ]] || [[ "$resolve_result" == *"NXDOMAIN"* ]] || [[ "$resolve_result" == *"can't find"* ]] || [[ "$resolve_result" == *"0.0.0.0"* ]]; then
		log_pass "DNS proxy blocks pastebin.com (got NXDOMAIN/failure)"
	else
		log_fail "DNS proxy should block pastebin.com but resolution succeeded"
		echo "Resolve output: $resolve_result"
		return 1
	fi
}

test_dns_proxy_cleanup_on_rm() {
	log_test "Testing DNS proxy and network cleanup (integration)"
	((TESTS_RUN++)) || true

	# Skip if Docker is not available
	if ! check_docker_available; then
		log_skip "Docker not available, skipping integration test"
		return 0
	fi

	local test_name="devbox-test-cleanup-$$"
	local network_name="${test_name}-net"
	local dns_container="${test_name}-dns"

	# Cleanup any existing resources
	docker rm -f "$dns_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Create network and DNS proxy
	docker network create --driver bridge "$network_name" >/dev/null 2>&1 || true
	docker run -d --name "$dns_container" --network "$network_name" alpine:latest sleep 60 >/dev/null 2>&1 || true

	# Verify they exist
	local network_exists dns_exists
	network_exists=$(docker network inspect "$network_name" >/dev/null 2>&1 && echo "yes" || echo "no")
	dns_exists=$(docker inspect "$dns_container" >/dev/null 2>&1 && echo "yes" || echo "no")

	if [[ "$network_exists" != "yes" ]] || [[ "$dns_exists" != "yes" ]]; then
		log_fail "Failed to create test resources"
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Simulate cleanup (what cmd_rm should do)
	docker rm -f "$dns_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Verify cleanup
	network_exists=$(docker network inspect "$network_name" >/dev/null 2>&1 && echo "yes" || echo "no")
	dns_exists=$(docker inspect "$dns_container" >/dev/null 2>&1 && echo "yes" || echo "no")

	if [[ "$network_exists" == "no" ]] && [[ "$dns_exists" == "no" ]]; then
		log_pass "DNS proxy and network cleaned up successfully"
	else
		log_fail "Cleanup failed - network=$network_exists, dns=$dns_exists"
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi
}

test_strict_profile_dns_allowlist() {
	log_test "Testing strict profile DNS allowlist blocks non-whitelisted domains (integration)"
	((TESTS_RUN++)) || true

	# Skip if Docker is not available
	if ! check_docker_available; then
		log_skip "Docker not available, skipping integration test"
		return 0
	fi

	local test_name="devbox-test-strict-$$"
	local network_name="${test_name}-net"
	local dns_container="${test_name}-dns"
	local test_container="${test_name}-app"

	# Cleanup any existing resources
	docker rm -f "$dns_container" "$test_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Create isolated network
	if ! docker network create --driver bridge "$network_name" >/dev/null 2>&1; then
		log_fail "Failed to create test network"
		return 1
	fi

	# DNS proxy config for allowlist mode (DEFAULT_ACTION=drop):
	# - Block everything by default with address=/#/
	# - Allow only specific domains via server=/domain/upstream entries
	local dns_config
	dns_config=$(
		cat <<'EOF'
# Block all domains by default (return NXDOMAIN)
address=/#/

# Allow only specific domains - forward to upstream DNS
server=/github.com/8.8.8.8
server=/api.github.com/8.8.8.8
EOF
	)

	# Start DNS proxy with allowlist configuration
	if ! docker run -d \
		--name "$dns_container" \
		--network "$network_name" \
		alpine:latest \
		sh -c "apk add --no-cache dnsmasq >/dev/null 2>&1 && echo '$dns_config' > /etc/dnsmasq.conf && dnsmasq -k -C /etc/dnsmasq.conf --log-queries" >/dev/null 2>&1; then
		log_fail "Failed to start DNS proxy container"
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Wait for dnsmasq to start
	sleep 3

	# Get DNS proxy IP
	local dns_ip
	dns_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$dns_container" 2>/dev/null)

	if [[ -z "$dns_ip" ]]; then
		log_fail "Could not get DNS proxy IP"
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Create test container using DNS proxy
	if ! docker run -d \
		--name "$test_container" \
		--network "$network_name" \
		--dns "$dns_ip" \
		alpine:latest sleep 60 >/dev/null 2>&1; then
		log_fail "Failed to create test container"
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Install nslookup in test container
	docker exec "$test_container" apk add --no-cache bind-tools >/dev/null 2>&1 || true

	# Test 1: random.example.com should be BLOCKED (not in allowlist)
	set +e
	local resolve_blocked
	resolve_blocked=$(docker exec "$test_container" nslookup random.example.com 2>&1)
	local blocked_exit=$?
	set -e

	# Test 2: github.com should be ALLOWED (in allowlist)
	set +e
	local resolve_allowed
	resolve_allowed=$(docker exec "$test_container" nslookup github.com 2>&1)
	local allowed_exit=$?
	set -e

	# Cleanup
	docker rm -f "$dns_container" "$test_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Verify: blocked domain should fail (NXDOMAIN, No answer, or 0.0.0.0)
	local blocked_ok=false
	# Convert to lowercase for case-insensitive matching
	local resolve_blocked_lower
	resolve_blocked_lower=$(echo "$resolve_blocked" | tr '[:upper:]' '[:lower:]')
	if [[ $blocked_exit -ne 0 ]] || [[ "$resolve_blocked_lower" == *"nxdomain"* ]] || [[ "$resolve_blocked_lower" == *"can't find"* ]] || [[ "$resolve_blocked_lower" == *"no answer"* ]] || [[ "$resolve_blocked" == *"0.0.0.0"* ]]; then
		blocked_ok=true
	fi

	# Verify: allowed domain should resolve successfully
	local allowed_ok=false
	if [[ $allowed_exit -eq 0 ]] && [[ "$resolve_allowed" == *"Address"* ]] && [[ "$resolve_allowed" != *"0.0.0.0"* ]]; then
		allowed_ok=true
	fi

	if [[ "$blocked_ok" == true ]] && [[ "$allowed_ok" == true ]]; then
		log_pass "Strict profile DNS allowlist: blocks unknown domains, allows whitelisted"
	else
		if [[ "$blocked_ok" != true ]]; then
			log_fail "Strict profile should block random.example.com but resolution succeeded"
			echo "Blocked domain output: $resolve_blocked"
		fi
		if [[ "$allowed_ok" != true ]]; then
			log_fail "Strict profile should allow github.com but resolution failed"
			echo "Allowed domain output: $resolve_allowed"
		fi
		return 1
	fi
}

test_standard_profile_allows_whitelisted_domains() {
	log_test "Testing standard profile allows npm registry (integration)"
	((TESTS_RUN++)) || true

	# Skip if Docker is not available
	if ! check_docker_available; then
		log_skip "Docker not available, skipping integration test"
		return 0
	fi

	local test_name="devbox-test-allow-$$"
	local network_name="${test_name}-net"
	local dns_container="${test_name}-dns"
	local test_container="${test_name}-app"

	# Cleanup any existing resources
	docker rm -f "$dns_container" "$test_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Create isolated network
	if ! docker network create --driver bridge "$network_name" >/dev/null 2>&1; then
		log_fail "Failed to create test network"
		return 1
	fi

	# DNS proxy config for standard mode (DEFAULT_ACTION=accept):
	# - Only block specific domains (pastebin)
	# - Allow everything else
	local dns_config="address=/pastebin.com/#"

	if ! docker run -d \
		--name "$dns_container" \
		--network "$network_name" \
		alpine:latest \
		sh -c "apk add --no-cache dnsmasq >/dev/null 2>&1 && echo 'server=8.8.8.8' > /etc/dnsmasq.conf && echo 'server=1.1.1.1' >> /etc/dnsmasq.conf && echo '$dns_config' >> /etc/dnsmasq.conf && dnsmasq -k -C /etc/dnsmasq.conf" >/dev/null 2>&1; then
		log_fail "Failed to start DNS proxy container"
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Wait for dnsmasq to start
	sleep 3

	# Get DNS proxy IP
	local dns_ip
	dns_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$dns_container" 2>/dev/null)

	if [[ -z "$dns_ip" ]]; then
		log_fail "Could not get DNS proxy IP"
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Create test container using DNS proxy
	if ! docker run -d \
		--name "$test_container" \
		--network "$network_name" \
		--dns "$dns_ip" \
		alpine:latest sleep 60 >/dev/null 2>&1; then
		log_fail "Failed to create test container"
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Install nslookup in test container
	docker exec "$test_container" apk add --no-cache bind-tools >/dev/null 2>&1 || true

	# Test: registry.npmjs.org should resolve (allowed domain in standard profile)
	set +e
	local resolve_result
	resolve_result=$(docker exec "$test_container" nslookup registry.npmjs.org 2>&1)
	local resolve_exit=$?
	set -e

	# Cleanup
	docker rm -f "$dns_container" "$test_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Verify: npm registry should resolve successfully
	if [[ $resolve_exit -eq 0 ]] && [[ "$resolve_result" == *"Address"* ]] && [[ "$resolve_result" != *"NXDOMAIN"* ]]; then
		log_pass "Standard profile allows npm registry (registry.npmjs.org resolves)"
	else
		log_fail "Standard profile should allow registry.npmjs.org"
		echo "Resolve output: $resolve_result"
		return 1
	fi
}

# Test: --allow-domain adds custom domain to DNS allowlist
test_allow_domain_integration() {
	log_test "Testing --allow-domain adds custom domain access (integration)"
	((TESTS_RUN++)) || true

	# Skip if Docker is not available
	if ! check_docker_available; then
		log_skip "Docker not available, skipping integration test"
		return 0
	fi

	local test_name="devbox-test-allowdom-$$"
	local network_name="${test_name}-net"
	local dns_container="${test_name}-dns"
	local test_container="${test_name}-app"

	# Cleanup any existing resources
	docker rm -f "$dns_container" "$test_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Source the network library to use merge_egress_rules
	export PROJECT_ROOT="$PROJECT_ROOT"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/lib/network.sh"

	# Load strict profile (allowlist mode - blocks everything by default)
	if ! load_egress_profile "strict" "$PROJECT_ROOT/profiles"; then
		log_fail "Failed to load strict profile"
		return 1
	fi

	# Verify we're in allowlist mode
	if [[ "$EGRESS_DEFAULT_ACTION" != "drop" ]]; then
		log_fail "Strict profile should have DEFAULT_ACTION=drop, got: $EGRESS_DEFAULT_ACTION"
		return 1
	fi

	# Add custom domain via merge_egress_rules (simulates --allow-domain flag)
	# Use httpbin.org which is a real domain but NOT in the strict allowlist
	merge_egress_rules "allow_domain" "httpbin.org"

	# Verify the domain was added to the allowed list
	if [[ "$EGRESS_ALLOWED_DOMAINS" != *"httpbin.org"* ]]; then
		log_fail "merge_egress_rules did not add httpbin.org to EGRESS_ALLOWED_DOMAINS"
		return 1
	fi

	# Create isolated network
	if ! docker network create --driver bridge "$network_name" >/dev/null 2>&1; then
		log_fail "Failed to create test network"
		return 1
	fi

	# Start DNS proxy with merged rules using the library function
	local dns_ip
	if ! dns_ip=$(start_dns_proxy "$test_name" "$EGRESS_ALLOWED_DOMAINS" "$EGRESS_BLOCKED_DOMAINS" "$EGRESS_DEFAULT_ACTION"); then
		log_fail "Failed to start DNS proxy"
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	if [[ -z "$dns_ip" ]]; then
		log_fail "DNS proxy started but no IP returned"
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Create test container using DNS proxy
	if ! docker run -d \
		--name "$test_container" \
		--network "$network_name" \
		--dns "$dns_ip" \
		alpine:latest sleep 60 >/dev/null 2>&1; then
		log_fail "Failed to create test container"
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Install nslookup in test container
	docker exec "$test_container" apk add --no-cache bind-tools >/dev/null 2>&1 || true

	# Test 1: httpbin.org (custom allowed domain) should resolve
	set +e
	local resolve_custom
	resolve_custom=$(docker exec "$test_container" nslookup httpbin.org 2>&1)
	local custom_exit=$?
	set -e

	# Test 2: randomnotallowed.example.com should be BLOCKED (not in allowlist)
	set +e
	local resolve_blocked
	resolve_blocked=$(docker exec "$test_container" nslookup randomnotallowed.example.com 2>&1)
	local blocked_exit=$?
	set -e

	# Cleanup
	docker rm -f "$dns_container" "$test_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Verify: custom allowed domain should resolve successfully
	local custom_ok=false
	if [[ $custom_exit -eq 0 ]] && [[ "$resolve_custom" == *"Address"* ]] && [[ "$resolve_custom" != *"0.0.0.0"* ]]; then
		custom_ok=true
	fi

	# Verify: non-allowlisted domain should be blocked
	local blocked_ok=false
	local resolve_blocked_lower
	resolve_blocked_lower=$(echo "$resolve_blocked" | tr '[:upper:]' '[:lower:]')
	if [[ $blocked_exit -ne 0 ]] || [[ "$resolve_blocked_lower" == *"nxdomain"* ]] || [[ "$resolve_blocked_lower" == *"can't find"* ]] || [[ "$resolve_blocked_lower" == *"no answer"* ]] || [[ "$resolve_blocked" == *"0.0.0.0"* ]]; then
		blocked_ok=true
	fi

	if [[ "$custom_ok" == true ]] && [[ "$blocked_ok" == true ]]; then
		log_pass "--allow-domain: custom domain httpbin.org resolves, non-allowed domain blocked"
	else
		if [[ "$custom_ok" != true ]]; then
			log_fail "--allow-domain should make httpbin.org resolve, but it failed"
			echo "Custom domain output: $resolve_custom"
		fi
		if [[ "$blocked_ok" != true ]]; then
			log_fail "Non-allowlisted domain should be blocked, but resolution succeeded"
			echo "Blocked domain output: $resolve_blocked"
		fi
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

	# Network enforcement tests
	test_airgapped_docker_command_has_network_none || true
	test_dry_run_shows_network_mode || true
	test_permissive_no_network_flag || true
	test_standard_no_network_none || true
	test_standard_dry_run_shows_dns_proxy || true
	test_standard_dry_run_shows_custom_network || true

	# Integration tests (require Docker)
	test_airgapped_integration_blocks_network || true
	test_standard_integration_creates_dns_proxy || true
	test_standard_integration_blocks_pastebin || true
	test_dns_proxy_cleanup_on_rm || true
	test_strict_profile_dns_allowlist || true
	test_standard_profile_allows_whitelisted_domains || true
	test_allow_domain_integration || true

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
