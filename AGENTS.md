# Agent Development Learnings

## CLI Development Best Practices

### Test-Driven Development for CLI Tools

**Learning**: When building CLI tools, create comprehensive test suites early to validate core functionality.

**Implementation**:
- Created `tests/test_cli_basic.sh` with 6 core tests covering help, error handling, permissions, and command parsing
- Used bash test patterns with proper exit code handling (`|| true`) to prevent test failures from stopping execution
- Captured command output in variables to enable reliable string matching without pipe interference

**Key Insights**:
- CLI tools need robust error handling for missing dependencies (Docker daemon)
- Help systems should be accessible via multiple entry points (`help`, `-h`, `--help`, no args)
- Colored output improves UX but requires proper escape sequence handling

### Bash Script Structure for Complex CLIs

**Learning**: Well-structured bash scripts benefit from clear separation of concerns and helper functions.

**Implementation**:
```bash
# Constants at top
readonly DEVBOX_IMAGE="devbox-base:latest"
readonly CONTAINER_PREFIX="devbox-"

# Logging functions for consistent output
log_info() { echo -e "${BLUE}INFO:${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

# Validation functions
check_docker() { ... }
ensure_image() { ... }
resolve_container() { ... }

# Command implementations as separate functions
cmd_init() { ... }
cmd_create() { ... }

# Main dispatcher
main() {
    case "$1" in
        init) cmd_init "$@" ;;
        ...
    esac
}
```

**Key Insights**:
- Helper functions reduce code duplication and improve maintainability
- Color constants should be defined as readonly variables
- Error messages should go to stderr (`>&2`)
- Command validation should happen before expensive operations (Docker image building)

### Docker Integration Patterns

**Learning**: CLI tools wrapping Docker need careful dependency checking and image management.

**Implementation**:
- `check_docker()` validates Docker daemon accessibility before any operations
- `ensure_image()` builds base image on-demand if missing
- Container name resolution supports both human names and Docker IDs
- Proper cleanup and resource management considerations

**Key Insights**:
- Always check `docker info` before attempting Docker operations
- Image building should be automatic but not repeated unnecessarily
- Container naming conventions need consistent prefixing for management

### Error Handling and User Experience

**Learning**: CLI tools should provide clear, actionable error messages with appropriate exit codes.

**Implementation**:
- Separate functions for different log levels with consistent formatting
- Unknown commands show the error AND help text
- Missing dependencies provide specific instructions
- Exit codes follow Unix conventions (0 = success, 1 = error)

**Key Insights**:
- Users need context when commands fail
- Help text should be easily accessible
- Color coding helps users quickly identify status

## Development Workflow Insights

### Incremental Implementation Strategy

**Learning**: For complex projects, implement core structure first, then add functionality incrementally.

**Approach Used**:
1. Built foundation (Docker images, scripts) - Phase 1 ✓
2. Created CLI structure and basic validation - Phase 2 (current)
3. Plan to implement individual commands one by one
4. Add polish and error handling iteratively

**Benefits**:
- Early validation of architecture decisions
- Testable milestones at each step
- Easier debugging when issues arise
- Clear progress tracking

### Testing Strategy for System Integration

**Learning**: CLI tools that integrate with external systems (Docker) need multiple test layers.

**Test Levels Implemented**:
1. **Unit tests**: Basic script functionality, argument parsing, help text
2. **Integration tests**: Docker daemon interaction, volume management
3. **End-to-end tests**: Full workflow testing (planned)

**Advanced Testing Patterns**:
- **Dry-run modes**: Enable testing complex commands without side effects (`--dry-run` flag)
- **Dedicated test files**: Created `test_init.sh` for comprehensive command-specific testing
- **Docker integration testing**: Tests volume creation, cleanup, and error scenarios
- **Flag combination testing**: Validates multiple flags work together correctly

**Key Insights**:
- Start with unit tests for quick feedback
- Dry-run modes are essential for testing destructive operations safely
- Integration tests should include cleanup and error scenarios
- Test files should be self-contained with proper setup/teardown

## Technical Decisions and Trade-offs

### Bash vs Other Languages

**Decision**: Used Bash for the CLI tool despite complexity.

**Rationale**:
- Direct Docker CLI integration without wrapper libraries
- Familiar to DevOps/infrastructure audience
- Minimal deployment dependencies
- Shell features (pipes, redirection) naturally fit CLI workflows

**Trade-offs**:
- More complex error handling than higher-level languages
- String manipulation can be verbose
- Testing requires bash-specific patterns

### Image Building Strategy

**Decision**: Build Docker image on-demand rather than requiring pre-built images.

**Benefits**:
- Simpler user onboarding (no separate build step)
- Ensures image is always available when needed
- Reduces external dependencies

**Trade-offs**:
- First run has additional latency
- Requires Docker daemon and build context access
- More complex error handling for build failures

### Command Implementation Patterns

**Learning**: Follow consistent patterns when implementing new CLI commands for maintainability.

**Pattern Applied (devbox logs)**:
1. **Flag parsing loop**: Iterate through all arguments with proper case matching
2. **Help text first**: Check for `--help/-h` before any validation
3. **Argument validation**: Validate required arguments after parsing all flags
4. **Container resolution**: Use shared `resolve_container()` helper for name/ID lookup
5. **Dry-run support**: Add `--dry-run` flag for testing without side effects
6. **Display name formatting**: Strip prefixes for cleaner user-facing output

**Implementation Structure**:
```bash
cmd_logs() {
    local container_name=""
    local follow=false
    local tail_lines=""
    local dry_run=false

    # Parse arguments and flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --follow|-f) follow=true; shift ;;
            --tail) tail_lines="$2"; shift 2 ;;
            --help|-h) show_help; return 0 ;;
            --*) log_error "Unknown option: $1"; return 1 ;;
            *) container_name="$1"; shift ;;
        esac
    done

    # Validate required arguments
    [[ -z "$container_name" ]] && log_error "..." && return 1

    # Resolve container
    container_id=$(resolve_container "$container_name") || return 1

    # Build and execute command
    docker_cmd="docker logs $options $container_id"
    eval "$docker_cmd"
}
```

**Key Insights**:
- Short flags (`-f`) and long flags (`--follow`) should be handled together
- Options requiring arguments need validation before shifting
- Dry-run mode enables comprehensive testing without actual execution
- Info messages should be contextual (e.g., suppressed when following logs)
- All commands benefit from consistent structure

### Test Coverage Strategies

**Learning**: Comprehensive tests should cover all command aspects, not just happy paths.

**Test Categories for CLI Commands** (applied to `devbox logs`):
1. **Help and documentation**: Help flag, usage messages
2. **Argument validation**: Missing arguments, too many arguments, invalid container names
3. **Flag parsing**: Each flag individually, combinations of flags, invalid flags
4. **Container states**: Running containers, stopped containers, nonexistent containers
5. **Alternative inputs**: Container names, short IDs, full IDs
6. **Edge cases**: Dry-run mode, multiple flags together

**Test Implementation Pattern**:
```bash
test_feature() {
    log_test "Testing feature description"
    ((TESTS_RUN++))

    # Setup test environment
    container=$(create_test_container "testname")

    # Execute test
    if output=$("$DEVBOX_BIN" command args 2>&1); then
        # Validate success output
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

**Key Insights**:
- Create dedicated test containers with predictable behavior
- Test both success and failure paths
- Verify error messages contain helpful information
- Use dry-run mode to test complex operations safely
- Separate test files per command keep test suites manageable

### Handling Variable-Length Command Arguments

**Learning**: Commands that execute arbitrary user commands (like `exec`) require special handling for argument parsing and quoting.

**Challenge**: `devbox exec <container> <command> [args...]` needs to:
1. Parse the container name
2. Handle optional flags like `-it` for interactive mode
3. Capture all remaining arguments as the command to execute
4. Properly quote arguments when building the docker command

**Implementation Pattern** (applied to `devbox exec`):
```bash
cmd_exec() {
    local container_name=""
    local exec_command=()
    local interactive_flags=""

    # Parse arguments and flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -it|-ti)
                interactive_flags="-it"
                shift
                ;;
            --help|-h)
                # Show help and return
                return 0
                ;;
            *)
                if [[ -z "$container_name" ]]; then
                    container_name="$1"
                    shift
                else
                    # Everything else is the command
                    exec_command+=("$@")
                    break  # Break to preserve all remaining args
                fi
                ;;
        esac
    done

    # Build docker exec command with proper quoting
    local docker_cmd="docker exec"

    if [[ -n "$interactive_flags" ]]; then
        docker_cmd="$docker_cmd $interactive_flags"
    fi

    docker_cmd="$docker_cmd $container_id"

    # Quote arguments that contain spaces
    for arg in "${exec_command[@]}"; do
        if [[ "$arg" =~ [[:space:]] ]]; then
            docker_cmd="$docker_cmd \"$arg\""
        else
            docker_cmd="$docker_cmd $arg"
        fi
    done

    # Use eval to execute with proper quoting
    eval "$docker_cmd"
}
```

**Key Insights**:
- Use `"$@"` to capture all remaining arguments at once
- Use `break` after capturing variable args to preserve them all
- Store command arguments in an array for flexibility
- Properly quote arguments containing spaces when building shell commands
- Use `eval` carefully when executing constructed commands
- Test with commands that have multiple args and special characters

**Testing Considerations**:
- Test simple commands: `echo "hello"`
- Test commands with multiple args: `sh -c "echo arg1 && echo arg2"`
- Test interactive mode flag passthrough
- Test with both container names and IDs
- Test error cases: missing container, missing command, stopped container

## Lessons for Future Agent Development

1. **Start with structure, then functionality** - CLI scaffolding paid dividends
2. **Test early and often** - Unit tests caught edge cases in argument handling
3. **Plan for user experience** - Color coding and clear error messages matter
4. **Document decisions** - Architecture choices need rationale for future reference
5. **Incremental validation** - Each phase should have working, testable output
6. **Follow TDD rigorously** - Write tests first, implement to pass, refactor if needed
7. **Reuse patterns** - Consistent command structure makes codebase predictable and maintainable
8. **Handle variable arguments carefully** - Commands that take arbitrary user input need special parsing and quoting logic
