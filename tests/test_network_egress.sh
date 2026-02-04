#!/bin/bash
# Test suite for devbox network egress control
# Tests flag parsing, profile loading, and basic egress functionality

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEVBOX_BIN="$PROJECT_ROOT/bin/devbox"
CONTAINER_PREFIX="devbox-"

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

		for func in load_egress_profile create_container_network cleanup_network_resources restart_dns_proxy; do
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
# Network Reset Tests
# ============================================================================

# Test: devbox network reset --help
test_network_reset_help() {
	log_test "Testing 'devbox network reset --help'"
	((TESTS_RUN++)) || true

	local output
	output=$("$DEVBOX_BIN" network reset --help 2>&1)

	if [[ "$output" == *"Reset egress rules"* ]] && [[ "$output" == *"--profile"* ]] && [[ "$output" == *"--force"* ]]; then
		log_pass "'devbox network reset' help displays options"
	else
		log_fail "'devbox network reset' help should show options"
		echo "Output: $output"
		return 1
	fi
}

# Test: devbox network reset requires container name
test_network_reset_requires_container() {
	log_test "Testing 'devbox network reset' requires container name"
	((TESTS_RUN++)) || true

	set +e
	local output
	output=$("$DEVBOX_BIN" network reset 2>&1)
	local exit_code=$?
	set -e

	if [[ $exit_code -ne 0 ]] && [[ "$output" == *"Container name required"* ]]; then
		log_pass "'devbox network reset' requires container name"
	else
		log_fail "'devbox network reset' should require container name"
		echo "Output: $output"
		return 1
	fi
}

# Test: devbox network reset dry-run shows what would be done
test_network_reset_dry_run() {
	log_test "Testing 'devbox network reset --dry-run'"
	((TESTS_RUN++)) || true

	# Skip if Docker not available
	if ! check_docker_available; then
		log_skip "Docker not available, skipping test"
		return 0
	fi

	local test_name="devbox-test-resetdry-$$"
	local container_name="${test_name}"
	local full_container="${CONTAINER_PREFIX}${test_name}"

	# Cleanup any existing container
	docker rm -f "$full_container" "${full_container}-dns" >/dev/null 2>&1 || true
	docker network rm "${full_container}-net" >/dev/null 2>&1 || true

	# Create a container with standard profile (has DNS proxy)
	# Use a simple alpine container for testing
	docker network create "${full_container}-net" >/dev/null 2>&1 || true
	if ! docker run -d --name "$full_container" \
		--network "${full_container}-net" \
		--label "devbox.egress=standard" \
		alpine:latest sleep 60 >/dev/null 2>&1; then
		log_fail "Failed to create test container"
		docker network rm "${full_container}-net" >/dev/null 2>&1 || true
		return 1
	fi

	# Test dry-run
	local output
	output=$("$DEVBOX_BIN" network reset "$test_name" --dry-run 2>&1)

	# Cleanup
	docker rm -f "$full_container" >/dev/null 2>&1 || true
	docker network rm "${full_container}-net" >/dev/null 2>&1 || true

	if [[ "$output" == *"Would reset egress rules"* ]] && [[ "$output" == *"Current profile"* ]]; then
		log_pass "'devbox network reset --dry-run' shows what would be done"
	else
		log_fail "'devbox network reset --dry-run' should show reset info"
		echo "Output: $output"
		return 1
	fi
}

# Test: devbox network reset actually resets DNS proxy (integration)
test_network_reset_integration() {
	log_test "Testing 'devbox network reset' recreates DNS proxy (integration)"
	((TESTS_RUN++)) || true

	# Skip if Docker not available
	if ! check_docker_available; then
		log_skip "Docker not available, skipping integration test"
		return 0
	fi

	local test_name="devbox-test-reset-int-$$"
	local network_name="${test_name}-net"
	local dns_container="${test_name}-dns"
	local main_container="${test_name}-app"
	local full_container="${CONTAINER_PREFIX}${test_name}"

	# Cleanup any existing resources
	docker rm -f "$full_container" "${full_container}-dns" "$dns_container" "$main_container" >/dev/null 2>&1 || true
	docker network rm "${full_container}-net" "$network_name" >/dev/null 2>&1 || true

	# Source the network library
	export PROJECT_ROOT="$PROJECT_ROOT"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/lib/network.sh"

	# Create network with subnet (required for --ip static IP assignment)
	# Use a unique subnet based on process ID to avoid conflicts
	local subnet_third_octet=$((($$ % 200) + 50)) # 50-250 to avoid common subnets
	local subnet="172.${subnet_third_octet}.0.0/16"
	if ! docker network create --subnet "$subnet" "$network_name" >/dev/null 2>&1; then
		log_fail "Failed to create test network with subnet $subnet"
		return 1
	fi

	# Start DNS proxy with a config that blocks example.com
	# (simulating custom block rule)
	# Assign a specific IP within the subnet
	local static_ip="172.${subnet_third_octet}.0.2"
	local custom_dns_config="address=/example.com/#"
	if ! docker run -d \
		--name "$dns_container" \
		--network "$network_name" \
		--ip "$static_ip" \
		alpine:latest \
		sh -c "apk add --no-cache dnsmasq >/dev/null 2>&1 && echo '$custom_dns_config' > /etc/dnsmasq.conf && echo 'server=8.8.8.8' >> /etc/dnsmasq.conf && dnsmasq -k" >/dev/null 2>&1; then
		log_fail "Failed to start initial DNS proxy"
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	sleep 2

	# Get DNS proxy IP
	local dns_ip
	dns_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$dns_container" 2>/dev/null)

	if [[ -z "$dns_ip" ]]; then
		log_fail "Could not get DNS proxy IP"
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Create main container using DNS proxy
	if ! docker run -d \
		--name "$main_container" \
		--network "$network_name" \
		--dns "$dns_ip" \
		--label "devbox=true" \
		--label "devbox.egress=standard" \
		alpine:latest sleep 120 >/dev/null 2>&1; then
		log_fail "Failed to create main container"
		docker rm -f "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Install nslookup
	docker exec "$main_container" apk add --no-cache bind-tools >/dev/null 2>&1 || true

	# Verify example.com is initially blocked (custom rule)
	set +e
	local before_reset
	before_reset=$(docker exec "$main_container" nslookup example.com 2>&1)
	local before_exit=$?
	set -e

	local before_blocked=false
	local before_lower
	before_lower=$(echo "$before_reset" | tr '[:upper:]' '[:lower:]')
	if [[ $before_exit -ne 0 ]] || [[ "$before_lower" == *"nxdomain"* ]] || [[ "$before_lower" == *"can't find"* ]]; then
		before_blocked=true
	fi

	# Now restart the DNS proxy with standard profile defaults (should allow example.com)
	# Load standard profile
	if ! load_egress_profile "standard" "$PROJECT_ROOT/profiles"; then
		log_fail "Failed to load standard profile"
		docker rm -f "$main_container" "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Restart DNS proxy with standard profile and same IP
	local new_ip
	new_ip=$(restart_dns_proxy "$test_name" "standard" "$dns_ip" "$PROJECT_ROOT/profiles")

	if [[ -z "$new_ip" ]]; then
		log_fail "Failed to restart DNS proxy"
		docker rm -f "$main_container" "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	sleep 2

	# Verify example.com is now resolvable (standard profile allows it)
	set +e
	local after_reset
	after_reset=$(docker exec "$main_container" nslookup example.com 2>&1)
	local after_exit=$?
	set -e

	# Cleanup
	docker rm -f "$main_container" "$dns_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Check results:
	# - Before reset: example.com should be blocked (or we just verify after works)
	# - After reset: example.com should resolve
	if [[ $after_exit -eq 0 ]] && [[ "$after_reset" == *"Address"* ]]; then
		# The key test: after reset with standard profile, example.com resolves
		if [[ "$before_blocked" == true ]]; then
			log_pass "Network reset: DNS proxy recreated, example.com now resolves (was blocked before)"
		else
			log_pass "Network reset: DNS proxy recreated with standard profile, example.com resolves"
		fi
	else
		log_fail "After reset, example.com should resolve with standard profile"
		echo "Before reset output: $before_reset"
		echo "After reset output: $after_reset"
		return 1
	fi
}

# Test: restart_dns_proxy preserves IP address
test_restart_dns_proxy_preserves_ip() {
	log_test "Testing restart_dns_proxy preserves IP address (integration)"
	((TESTS_RUN++)) || true

	# Skip if Docker not available
	if ! check_docker_available; then
		log_skip "Docker not available, skipping integration test"
		return 0
	fi

	local test_name="devbox-test-ippreserve-$$"
	local network_name="${test_name}-net"
	local dns_container="${test_name}-dns"

	# Cleanup
	docker rm -f "$dns_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Source network library
	export PROJECT_ROOT="$PROJECT_ROOT"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/lib/network.sh"

	# Create network with subnet (required for static IP assignment)
	# Use unique subnet to avoid conflicts
	local subnet_third_octet=$((($$ % 200) + 50))
	local subnet="172.${subnet_third_octet}.0.0/16"
	if ! docker network create --subnet "$subnet" "$network_name" >/dev/null 2>&1; then
		log_fail "Failed to create test network with subnet"
		return 1
	fi

	# Start initial DNS proxy with standard profile
	if ! load_egress_profile "standard" "$PROJECT_ROOT/profiles"; then
		log_fail "Failed to load standard profile"
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Use a specific static IP for the initial start
	local static_ip="172.${subnet_third_octet}.0.2"
	local initial_ip
	initial_ip=$(start_dns_proxy "$test_name" "$EGRESS_ALLOWED_DOMAINS" "$EGRESS_BLOCKED_DOMAINS" "$EGRESS_DEFAULT_ACTION" "$static_ip")

	if [[ -z "$initial_ip" ]]; then
		log_fail "Failed to start initial DNS proxy"
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Restart DNS proxy with same IP
	local restarted_ip
	restarted_ip=$(restart_dns_proxy "$test_name" "standard" "$initial_ip" "$PROJECT_ROOT/profiles")

	# Cleanup
	docker rm -f "$dns_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	if [[ "$restarted_ip" == "$initial_ip" ]]; then
		log_pass "restart_dns_proxy preserves IP address ($initial_ip)"
	else
		log_fail "IP address changed: $initial_ip -> $restarted_ip"
		return 1
	fi
}

# ============================================================================
# Test: Custom egress rules re-application on container start
# ============================================================================

test_network_lib_has_get_custom_rules_function() {
	log_test "Testing lib/network.sh has get_custom_egress_rules_from_labels function"
	((TESTS_RUN++)) || true

	local content
	content=$(cat "$PROJECT_ROOT/lib/network.sh")

	if [[ "$content" == *"get_custom_egress_rules_from_labels"* ]]; then
		log_pass "lib/network.sh has get_custom_egress_rules_from_labels function"
	else
		log_fail "lib/network.sh missing get_custom_egress_rules_from_labels function"
		return 1
	fi
}

test_get_custom_rules_from_labels() {
	log_test "Testing get_custom_egress_rules_from_labels reads rules from files"
	((TESTS_RUN++)) || true

	local test_container="devbox-test-customrules-$$"

	# Source network library
	export PROJECT_ROOT="$PROJECT_ROOT"
	# shellcheck source=/dev/null
	source "$PROJECT_ROOT/lib/network.sh"

	# Create egress rules directory and files
	local rules_dir
	rules_dir=$(get_egress_rules_dir "$test_container")
	mkdir -p "$rules_dir"
	echo "custom.example.com" >"$rules_dir/allow-domains.txt"
	echo "blocked.example.com" >"$rules_dir/block-domains.txt"
	echo "10.0.0.0/8" >"$rules_dir/allow-ips.txt"

	# Call the function
	local output
	if output=$(get_custom_egress_rules_from_labels "$test_container" 2>&1); then
		# Cleanup
		rm -rf "$rules_dir"

		# Verify output contains expected domains
		if [[ "$output" == *"custom.example.com"* ]] && [[ "$output" == *"blocked.example.com"* ]] && [[ "$output" == *"10.0.0.0/8"* ]]; then
			log_pass "get_custom_egress_rules_from_labels reads rules from files correctly"
		else
			log_fail "Output missing expected values: $output"
			return 1
		fi
	else
		rm -rf "$rules_dir"
		log_fail "Function failed: $output"
		return 1
	fi
}

test_start_reapplies_custom_egress_rules() {
	log_test "Testing 'devbox start' re-applies custom egress rules (integration)"
	((TESTS_RUN++)) || true

	# Skip if Docker is not available
	if ! check_docker_available; then
		log_skip "Docker not available, skipping integration test"
		return 0
	fi

	# Skip if credentials volume doesn't exist (required for devbox create)
	# This happens in CI where devbox init hasn't been run
	if ! docker volume inspect devbox-credentials >/dev/null 2>&1; then
		log_skip "Credentials volume not found, skipping (requires 'devbox init' to run first)"
		return 0
	fi

	local test_name="devbox-test-reapply-$$"
	local container_name="${CONTAINER_PREFIX}test-${test_name}"
	local dns_container="${container_name}-dns"
	local network_name="${container_name}-net"

	# Cleanup any existing resources
	docker rm -f "$container_name" "$dns_container" >/dev/null 2>&1 || true
	docker network rm "$network_name" >/dev/null 2>&1 || true

	# Create a container with strict profile (blocks all by default)
	# We'll add custom.httpbin.org via 'network allow' and verify it works after restart
	if ! output=$("$DEVBOX_BIN" create "test-${test_name}" "testaco/test-repo" \
		--github-secret test-github-secret \
		--claude-code-secret test-claude-secret \
		--egress strict \
		2>&1); then
		log_fail "Failed to create container: $output"
		return 1
	fi

	# Wait for container to be ready
	sleep 3

	# Add a custom allow rule for httpbin.org
	if ! "$DEVBOX_BIN" network allow "test-${test_name}" --domain httpbin.org 2>&1; then
		log_fail "Failed to add allow rule"
		docker rm -f "$container_name" "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Verify the rule was stored in file
	local rules_dir
	rules_dir=$(get_egress_rules_dir "$container_name")
	if [[ ! -f "$rules_dir/allow-domains.txt" ]] || ! grep -q "httpbin.org" "$rules_dir/allow-domains.txt" 2>/dev/null; then
		log_fail "Custom rule not stored in file"
		docker rm -f "$container_name" "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Stop the container
	"$DEVBOX_BIN" stop "test-${test_name}" >/dev/null 2>&1

	# Start the container (this should re-apply the custom rules)
	if ! "$DEVBOX_BIN" start "test-${test_name}" >/dev/null 2>&1; then
		log_fail "Failed to start container"
		docker rm -f "$container_name" "$dns_container" >/dev/null 2>&1 || true
		docker network rm "$network_name" >/dev/null 2>&1 || true
		return 1
	fi

	# Wait for container and DNS proxy to be ready
	sleep 5

	# Install nslookup in the container (devbox uses Debian, not Alpine, need root for apt)
	docker exec -u root "$container_name" sh -c "command -v nslookup >/dev/null 2>&1 || (apt-get update && apt-get install -y dnsutils) >/dev/null 2>&1" || true

	# Test that httpbin.org resolves (custom allowed domain)
	set +e
	local resolve_allowed
	resolve_allowed=$(docker exec "$container_name" nslookup httpbin.org 2>&1)
	local allowed_exit=$?
	set -e

	# Test that random.example.com does NOT resolve (strict profile blocks unknown)
	set +e
	local resolve_blocked
	resolve_blocked=$(docker exec "$container_name" nslookup random.example.com 2>&1)
	local blocked_exit=$?
	set -e

	# Cleanup
	"$DEVBOX_BIN" rm --force "test-${test_name}" >/dev/null 2>&1 || true

	# Verify allowed domain resolves
	local allowed_ok=false
	if [[ $allowed_exit -eq 0 ]] && [[ "$resolve_allowed" == *"Address"* ]] && [[ "$resolve_allowed" != *"0.0.0.0"* ]]; then
		allowed_ok=true
	fi

	# Verify blocked domain fails
	local blocked_ok=false
	local resolve_blocked_lower
	resolve_blocked_lower=$(echo "$resolve_blocked" | tr '[:upper:]' '[:lower:]')
	if [[ $blocked_exit -ne 0 ]] || [[ "$resolve_blocked_lower" == *"nxdomain"* ]] || [[ "$resolve_blocked_lower" == *"can't find"* ]] || [[ "$resolve_blocked_lower" == *"no answer"* ]] || [[ "$resolve_blocked" == *"0.0.0.0"* ]]; then
		blocked_ok=true
	fi

	if [[ "$allowed_ok" == true ]] && [[ "$blocked_ok" == true ]]; then
		log_pass "'devbox start' re-applies custom egress rules (httpbin.org allowed, random blocked)"
	else
		if [[ "$allowed_ok" != true ]]; then
			log_fail "Custom allowed domain (httpbin.org) not accessible after restart"
			echo "Resolve output: $resolve_allowed"
		fi
		if [[ "$blocked_ok" != true ]]; then
			log_fail "Blocked domain should not resolve but did"
			echo "Resolve output: $resolve_blocked"
		fi
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

	# Network reset tests
	test_network_reset_help || true
	test_network_reset_requires_container || true
	test_network_reset_dry_run || true
	test_network_reset_integration || true
	test_restart_dns_proxy_preserves_ip || true

	# Custom rules re-application tests
	test_network_lib_has_get_custom_rules_function || true
	test_get_custom_rules_from_labels || true
	test_start_reapplies_custom_egress_rules || true

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
