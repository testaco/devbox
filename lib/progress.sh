#!/bin/bash
# Progress indicator library for devbox CLI
# Provides spinner animations for long-running operations

# Include guard to prevent multiple sourcing
if [[ -n "${_DEVBOX_PROGRESS_LOADED:-}" ]]; then
	return 0
fi
_DEVBOX_PROGRESS_LOADED=1

# Spinner state
SPINNER_PID=""
SPINNER_MESSAGE=""

# Spinner characters (Unicode braille patterns for smooth animation)
SPINNER_CHARS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

# Colors
PROGRESS_BLUE='\033[0;34m'
PROGRESS_GREEN='\033[0;32m'
PROGRESS_RED='\033[0;31m'
PROGRESS_NC='\033[0m'

# Check if we're running in a terminal that supports spinners
is_terminal() {
	# Check if stdout is a terminal
	[[ -t 1 ]] && [[ -z "${DEVBOX_NO_SPINNER:-}" ]] && [[ -z "${CI:-}" ]]
}

# Internal spinner loop function
_spinner_loop() {
	local message="$1"
	local i=0
	local len=${#SPINNER_CHARS}

	# Hide cursor
	tput civis 2>/dev/null || true

	while true; do
		local char="${SPINNER_CHARS:$i:1}"
		printf "\r${PROGRESS_BLUE}%s${PROGRESS_NC} %s" "$char" "$message"
		i=$(((i + 1) % len))
		sleep 0.1
	done
}

# Start a spinner with the given message
# Usage: start_spinner "Building image..."
start_spinner() {
	local message="${1:-Working...}"
	SPINNER_MESSAGE="$message"

	# If not in a terminal, just print the message
	if ! is_terminal; then
		echo -e "${PROGRESS_BLUE}...${PROGRESS_NC} $message"
		return 0
	fi

	# Kill any existing spinner
	stop_spinner 2>/dev/null || true

	# Start the spinner in the background
	_spinner_loop "$message" &
	SPINNER_PID=$!

	# Disable job control messages
	disown "$SPINNER_PID" 2>/dev/null || true
}

# Stop the spinner and show success/failure
# Usage: stop_spinner [exit_code]
#   exit_code: 0 = success (green check), non-zero = failure (red X)
stop_spinner() {
	local exit_code="${1:-0}"

	# If no spinner is running, nothing to do
	if [[ -z "$SPINNER_PID" ]]; then
		return 0
	fi

	# Kill the spinner process
	if kill -0 "$SPINNER_PID" 2>/dev/null; then
		kill "$SPINNER_PID" 2>/dev/null || true
		wait "$SPINNER_PID" 2>/dev/null || true
	fi

	# Only show final status if we're in a terminal
	if is_terminal; then
		# Show cursor
		tput cnorm 2>/dev/null || true

		# Clear the line and show final status
		printf "\r\033[K"
		if [[ "$exit_code" -eq 0 ]]; then
			echo -e "${PROGRESS_GREEN}✓${PROGRESS_NC} $SPINNER_MESSAGE"
		else
			echo -e "${PROGRESS_RED}✗${PROGRESS_NC} $SPINNER_MESSAGE"
		fi
	fi

	SPINNER_PID=""
	SPINNER_MESSAGE=""
}

# Run a command with a spinner, showing progress
# Usage: with_spinner "Message" "command to run"
# Returns: The exit code of the command
with_spinner() {
	local message="$1"
	shift
	local cmd="$*"

	# If not in a terminal, just run the command with a simple message
	if ! is_terminal; then
		echo -e "${PROGRESS_BLUE}...${PROGRESS_NC} $message"
		local output
		local exit_code
		set +e
		output=$(eval "$cmd" 2>&1)
		exit_code=$?
		set -e

		if [[ $exit_code -eq 0 ]]; then
			echo -e "${PROGRESS_GREEN}✓${PROGRESS_NC} $message"
		else
			echo -e "${PROGRESS_RED}✗${PROGRESS_NC} $message"
		fi

		# Print any output
		if [[ -n "$output" ]]; then
			echo "$output"
		fi

		return $exit_code
	fi

	# Start the spinner
	start_spinner "$message"

	# Run the command and capture output
	local output
	local exit_code
	set +e
	output=$(eval "$cmd" 2>&1)
	exit_code=$?
	set -e

	# Stop the spinner with appropriate status
	stop_spinner "$exit_code"

	# Print any output
	if [[ -n "$output" ]]; then
		echo "$output"
	fi

	return $exit_code
}

# Cleanup function to ensure cursor is visible on exit
_progress_cleanup() {
	if [[ -n "$SPINNER_PID" ]]; then
		kill "$SPINNER_PID" 2>/dev/null || true
		# Only restore cursor if we actually had a spinner running
		tput cnorm 2>/dev/null || true
	fi
}

# Set up cleanup trap
trap _progress_cleanup EXIT
