#!/bin/bash
# Test suite for devbox bash completion

# Don't use -e because we want to capture test failures
set -uo pipefail

# Color codes for output
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPLETION_FILE="$PROJECT_ROOT/completions/devbox.bash"

# Logging functions
log_test() {
	echo -e "${BLUE}TEST:${NC} $*"
}

log_pass() {
	echo -e "${GREEN}✓ PASS:${NC} $*"
	((TESTS_PASSED++))
}

log_fail() {
	echo -e "${RED}✗ FAIL:${NC} $*"
	((TESTS_FAILED++))
}

log_skip() {
	echo -e "${BLUE}⊘ SKIP:${NC} $*"
}

# Helper function to test completion
# Usage: test_completion "devbox " expected_words...
test_completion_contains() {
	local input="$1"
	shift
	local expected_words=("$@")

	# Parse input into words
	local -a words
	IFS=' ' read -ra words <<<"$input"

	# Set completion variables
	COMP_WORDS=("${words[@]}")
	COMP_CWORD=$((${#words[@]} - 1))
	COMP_LINE="$input"
	COMP_POINT=${#COMP_LINE}

	local cur="${words[$COMP_CWORD]}"
	local prev=""
	if [[ $COMP_CWORD -gt 0 ]]; then
		prev="${words[$((COMP_CWORD - 1))]}"
	fi

	# Clear reply array
	COMPREPLY=()

	# Call completion function
	_devbox_completion

	# Check if all expected words are in COMPREPLY
	local all_found=true
	for expected in "${expected_words[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$expected" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			all_found=false
			break
		fi
	done

	if [[ "$all_found" == true ]]; then
		return 0
	else
		echo "Expected words not found: ${expected_words[*]}"
		echo "Got: ${COMPREPLY[*]}"
		return 1
	fi
}

# Setup
setup() {
	log_test "Setting up test environment"

	# Source the completion file
	if [[ ! -f "$COMPLETION_FILE" ]]; then
		echo "Error: Completion file not found at $COMPLETION_FILE"
		exit 1
	fi

	# Source bash completion library (if available)
	if [[ -f /usr/share/bash-completion/bash_completion ]]; then
		source /usr/share/bash-completion/bash_completion
	elif [[ -f /etc/bash_completion ]]; then
		source /etc/bash_completion
	fi

	# Define _init_completion if not available (fallback for minimal environments)
	if ! declare -f _init_completion >/dev/null; then
		_init_completion() {
			cur="${COMP_WORDS[COMP_CWORD]}"
			prev="${COMP_WORDS[COMP_CWORD - 1]}"
			words=("${COMP_WORDS[@]}")
			cword=$COMP_CWORD
		}
	fi

	source "$COMPLETION_FILE"

	log_pass "Test environment setup complete"
	echo
}

# Test: Command completion
test_command_completion() {
	log_test "Testing top-level command completion"
	((TESTS_RUN++))

	COMP_WORDS=("devbox" "")
	COMP_CWORD=1
	COMP_LINE="devbox "
	COMP_POINT=${#COMP_LINE}

	COMPREPLY=()
	_devbox_completion

	# Check that all commands are present
	local commands=("init" "create" "list" "attach" "stop" "start" "rm" "logs" "exec" "ports" "help")
	local all_found=true
	for cmd in "${commands[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$cmd" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			all_found=false
			log_fail "Command '$cmd' not found in completions"
			return 1
		fi
	done

	if [[ "$all_found" == true ]]; then
		log_pass "All commands present in completion"
	else
		log_fail "Some commands missing from completion"
		return 1
	fi
}

# Test: init command flags
test_init_flags() {
	log_test "Testing 'devbox init' flag completion"
	((TESTS_RUN++))

	COMP_WORDS=("devbox" "init" "")
	COMP_CWORD=2
	COMP_LINE="devbox init "
	COMP_POINT=${#COMP_LINE}

	COMPREPLY=()
	_devbox_completion

	# Check for expected flags
	local expected_flags=("--bedrock" "--import-aws" "--help" "-h")
	for flag in "${expected_flags[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$flag" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			log_fail "Flag '$flag' not found in init completions"
			return 1
		fi
	done

	log_pass "Init flags completion working"
}

# Test: create command flags
test_create_flags() {
	log_test "Testing 'devbox create' flag completion"
	((TESTS_RUN++))

	COMP_WORDS=("devbox" "create" "")
	COMP_CWORD=2
	COMP_LINE="devbox create "
	COMP_POINT=${#COMP_LINE}

	COMPREPLY=()
	_devbox_completion

	# Check for expected flags
	local expected_flags=("--port" "-p" "--bedrock" "--aws-profile" "--help" "-h")
	for flag in "${expected_flags[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$flag" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			log_fail "Flag '$flag' not found in create completions"
			return 1
		fi
	done

	log_pass "Create flags completion working"
}

# Test: logs command flags
test_logs_flags() {
	log_test "Testing 'devbox logs' flag completion"
	((TESTS_RUN++))

	COMP_WORDS=("devbox" "logs" "-")
	COMP_CWORD=2
	COMP_LINE="devbox logs -"
	COMP_POINT=${#COMP_LINE}

	COMPREPLY=()
	_devbox_completion

	# Check for expected flags
	local expected_flags=("--follow" "-f" "--tail" "--dry-run" "--help" "-h")
	for flag in "${expected_flags[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$flag" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			log_fail "Flag '$flag' not found in logs completions"
			return 1
		fi
	done

	log_pass "Logs flags completion working"
}

# Test: rm command flags
test_rm_flags() {
	log_test "Testing 'devbox rm' flag completion"
	((TESTS_RUN++))

	COMP_WORDS=("devbox" "rm" "-")
	COMP_CWORD=2
	COMP_LINE="devbox rm -"
	COMP_POINT=${#COMP_LINE}

	COMPREPLY=()
	_devbox_completion

	# Check for expected flags
	local expected_flags=("--force" "-f" "-a" "-af" "-fa" "--dry-run" "--help" "-h")
	for flag in "${expected_flags[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$flag" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			log_fail "Flag '$flag' not found in rm completions"
			return 1
		fi
	done

	log_pass "Rm flags completion working"
}

# Test: exec command flags
test_exec_flags() {
	log_test "Testing 'devbox exec' flag completion"
	((TESTS_RUN++))

	COMP_WORDS=("devbox" "exec" "-")
	COMP_CWORD=2
	COMP_LINE="devbox exec -"
	COMP_POINT=${#COMP_LINE}

	COMPREPLY=()
	_devbox_completion

	# Check for expected flags
	local expected_flags=("-it" "-ti" "--dry-run" "--help" "-h")
	for flag in "${expected_flags[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$flag" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			log_fail "Flag '$flag' not found in exec completions"
			return 1
		fi
	done

	log_pass "Exec flags completion working"
}

# Test: exec command completion suggests common commands
test_exec_command_suggestions() {
	log_test "Testing 'devbox exec <container>' command suggestions"
	((TESTS_RUN++))

	# Simulate: devbox exec mycontainer <tab>
	COMP_WORDS=("devbox" "exec" "mycontainer" "")
	COMP_CWORD=3
	COMP_LINE="devbox exec mycontainer "
	COMP_POINT=${#COMP_LINE}

	COMPREPLY=()
	_devbox_completion

	# Check for common commands
	local expected_cmds=("bash" "sh" "claude" "gh" "git")
	for cmd in "${expected_cmds[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$cmd" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			log_fail "Command '$cmd' not found in exec command completions"
			return 1
		fi
	done

	log_pass "Exec command suggestions working"
}

# Test: list command flags
test_list_flags() {
	log_test "Testing 'devbox list' flag completion"
	((TESTS_RUN++))

	COMP_WORDS=("devbox" "list" "-")
	COMP_CWORD=2
	COMP_LINE="devbox list -"
	COMP_POINT=${#COMP_LINE}

	COMPREPLY=()
	_devbox_completion

	# Check for expected flags
	local expected_flags=("--help" "-h")
	for flag in "${expected_flags[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$flag" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			log_fail "Flag '$flag' not found in list completions"
			return 1
		fi
	done

	log_pass "List flags completion working"
}

# Test: stop command flags
test_stop_flags() {
	log_test "Testing 'devbox stop' flag completion"
	((TESTS_RUN++))

	COMP_WORDS=("devbox" "stop" "--")
	COMP_CWORD=2
	COMP_LINE="devbox stop --"
	COMP_POINT=${#COMP_LINE}

	COMPREPLY=()
	_devbox_completion

	# Check for expected flags
	local expected_flags=("--dry-run" "--help")
	for flag in "${expected_flags[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$flag" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			log_fail "Flag '$flag' not found in stop completions"
			return 1
		fi
	done

	log_pass "Stop flags completion working"
}

# Test: start command flags
test_start_flags() {
	log_test "Testing 'devbox start' flag completion"
	((TESTS_RUN++))

	COMP_WORDS=("devbox" "start" "--")
	COMP_CWORD=2
	COMP_LINE="devbox start --"
	COMP_POINT=${#COMP_LINE}

	COMPREPLY=()
	_devbox_completion

	# Check for expected flags
	local expected_flags=("--dry-run" "--help")
	for flag in "${expected_flags[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$flag" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			log_fail "Flag '$flag' not found in start completions"
			return 1
		fi
	done

	log_pass "Start flags completion working"
}

# Test: ports command flags
test_ports_flags() {
	log_test "Testing 'devbox ports' flag completion"
	((TESTS_RUN++))

	COMP_WORDS=("devbox" "ports" "--")
	COMP_CWORD=2
	COMP_LINE="devbox ports --"
	COMP_POINT=${#COMP_LINE}

	COMPREPLY=()
	_devbox_completion

	# Check for expected flags
	local expected_flags=("--dry-run" "--help")
	for flag in "${expected_flags[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$flag" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			log_fail "Flag '$flag' not found in ports completions"
			return 1
		fi
	done

	log_pass "Ports flags completion working"
}

# Test: logs --tail suggests common values
test_logs_tail_suggestions() {
	log_test "Testing 'devbox logs --tail' value suggestions"
	((TESTS_RUN++))

	COMP_WORDS=("devbox" "logs" "mycontainer" "--tail" "")
	COMP_CWORD=4
	COMP_LINE="devbox logs mycontainer --tail "
	COMP_POINT=${#COMP_LINE}

	COMPREPLY=()
	_devbox_completion

	# Check for common tail values
	local expected_values=("10" "50" "100" "200" "500")
	for value in "${expected_values[@]}"; do
		local found=false
		for reply in "${COMPREPLY[@]}"; do
			if [[ "$reply" == "$value" ]]; then
				found=true
				break
			fi
		done
		if [[ "$found" == false ]]; then
			log_fail "Value '$value' not found in tail completions"
			return 1
		fi
	done

	log_pass "Logs --tail suggestions working"
}

# Run all tests
main() {
	echo "========================================"
	echo "Devbox Bash Completion Test Suite"
	echo "========================================"
	echo

	setup

	# Run tests
	test_command_completion || true
	test_init_flags || true
	test_create_flags || true
	test_logs_flags || true
	test_rm_flags || true
	test_exec_flags || true
	test_exec_command_suggestions || true
	test_list_flags || true
	test_stop_flags || true
	test_start_flags || true
	test_ports_flags || true
	test_logs_tail_suggestions || true

	# Summary
	echo
	echo "========================================"
	echo "Test Summary"
	echo "========================================"
	echo "Tests run:    $TESTS_RUN"
	echo "Tests passed: $TESTS_PASSED"
	echo "Tests failed: $TESTS_FAILED"
	echo

	if [[ $TESTS_FAILED -eq 0 ]]; then
		echo -e "${GREEN}All tests passed!${NC}"
		exit 0
	else
		echo -e "${RED}Some tests failed!${NC}"
		exit 1
	fi
}

# Run tests
main "$@"
