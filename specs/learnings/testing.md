# Testing Patterns

Testing strategies for CLI tools with Docker integration.

## Test Levels

1. **Unit tests**: Argument parsing, help text, basic validation
2. **Integration tests**: Docker interaction, volume management, container lifecycle

## Test Structure

```bash
test_feature() {
    log_test "Testing feature description"
    ((TESTS_RUN++)) || true  # || true needed with set -e

    # Setup
    container=$(create_test_container "testname")

    # Execute and validate
    if output=$("$DEVBOX_BIN" command args 2>&1); then
        if [[ "$output" == *"expected"* ]]; then
            log_pass "Test passed"
        else
            log_fail "Unexpected output: $output"
            return 1
        fi
    else
        log_fail "Command failed: $output"
        return 1
    fi
}
```

## Exit Code Capture

With `set -e`, capturing exit codes requires special handling:

```bash
# WRONG - || true overwrites the exit code
result=$(some_command) || true
echo $?  # Always 0!

# RIGHT - disable errexit temporarily
set +e
result=$(some_command)
exit_code=$?
set -e
```

## Test Categories

For each command, test:
1. Help flag (`--help`, `-h`)
2. Missing required arguments
3. Invalid arguments/flags
4. Container states (running, stopped, nonexistent)
5. Alternative inputs (names, short IDs, full IDs)
6. Flag combinations
7. Dry-run mode

## Environment Considerations

Tests run in shared environments. Handle conflicts:

```bash
# Always remove before creating
docker rm -f "$container_name" >/dev/null 2>&1 || true

# Use high ports (>15000)
container=$(create_test_container "test" "-p 18080:80")

# Validate container creation
if ! container=$(create_test_container "name"); then
    log_fail "Container creation failed"
    return 1
fi
```

Key points:
- Cleanup at start AND end of test suites
- Tests may run multiple times without full cleanup
- Use unique, high-numbered ports
- Make tests idempotent

## Dry-Run Testing

Add `--dry-run` flag to commands for safe testing:

```bash
if [[ "$dry_run" == true ]]; then
    echo "Would run: $docker_cmd"
    return 0
fi
```

## Integration Test Suite

Run after major changes:
```bash
tests/test_checkpoint3_integration.sh
```

Requires:
- `expect` package installed
- Either `devbox-github-token` secret or `GITHUB_TOKEN` env var
