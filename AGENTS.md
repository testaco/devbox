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

### Docker Inspection Patterns

**Learning**: Different Docker commands provide different information depending on container state.

**Challenge**: `docker port` returns empty output for stopped containers, but users need to see port mappings regardless of container state.

**Solution**: Use `docker inspect` with `HostConfig.PortBindings` which persists port configuration even when containers are stopped.

**Implementation**:
```bash
# Works for both running AND stopped containers
ports=$(docker inspect --format '{{range $p, $conf := .HostConfig.PortBindings}}{{range $conf}}{{$p}} -> {{if .HostIp}}{{.HostIp}}{{else}}0.0.0.0{{end}}:{{.HostPort}}{{"\n"}}{{end}}{{end}}' "$container_id" 2>/dev/null)
```

**Key Insights**:
- `docker port <container>` only works for running containers
- `docker inspect .NetworkSettings.Ports` shows runtime port state (empty when stopped)
- `docker inspect .HostConfig.PortBindings` shows configured ports regardless of state
- Template formatting in `--format` requires careful escaping and iteration
- Always default empty HostIp to "0.0.0.0" for clarity

### Test Environment Considerations

**Learning**: Tests must handle shared environments where resources (ports, container names) might conflict.

**Problems Encountered**:
1. Container names from previous test runs preventing new container creation
2. Port conflicts when tests use commonly-used ports (8080, 3000, 5000)
3. Tests silently failing when `docker run` fails but test continues

**Solutions Applied**:
```bash
# 1. Always remove before creating
docker rm -f "$container_name" >/dev/null 2>&1 || true

# 2. Use high-numbered, unique ports
container=$(create_test_container "oneport" "-p 18080:80")  # Not 8080

# 3. Validate container creation
if ! container=$(create_test_container "name"); then
    log_fail "Container creation failed"
    return 1
fi
```

**Key Insights**:
- Assume tests may run multiple times without full cleanup
- Use ports above 15000 to avoid conflicts with common services
- Make tests resilient to partial failures in previous runs
- Cleanup at start AND end of test suites

### Error Handling in Container Entrypoints

**Learning**: Container entrypoint scripts should provide comprehensive, actionable error messages when operations fail.

**Problem**: Users running containers face opaque failures when repositories fail to clone, configurations are missing, or environments fail to initialize. Default error messages from tools like `gh`, `git`, or `nix` are often cryptic.

**Solution**: Wrap critical operations in error handling that provides:
1. Clear visual separation (unicode box drawing characters)
2. Specific error context (what failed, what was expected)
3. Possible causes in bullet format
4. Step-by-step remediation instructions
5. Links to relevant documentation

**Implementation Pattern**:
```bash
# Before: Basic operation that exits on failure
gh repo clone "$REPO_URL" "$REPO_DIR"

# After: Comprehensive error handling
if ! gh repo clone "$REPO_URL" "$REPO_DIR" 2>&1; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✗ ERROR: Failed to clone repository"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Repository: $REPO_URL"
    echo ""
    echo "Possible causes:"
    echo "  • Repository does not exist or URL is incorrect"
    echo "  • You don't have access to this repository"
    echo "  • Network connectivity issues"
    echo "  • GitHub authentication issues"
    echo ""
    echo "To fix:"
    echo "  1. Verify the repository URL is correct"
    echo "  2. Ensure you have access to the repository"
    echo "  3. Check your GitHub authentication"
    echo "  4. Try re-running initialization"
    echo ""
    exit 1
fi
```

**Key Insights**:
- Use `set -e` at script start, then explicitly check command success for operations that need custom error messages
- Capture stderr with `2>&1` to see actual error output before showing custom message
- Visual separators (━ character) make errors stand out in logs
- Success messages (`✓`) provide positive feedback and help users track progress
- Include the actual values (repo URL, file path) in error messages for debugging
- Provide examples of valid configurations for missing-config errors
- Link to official documentation for complex topics (like Nix flakes)

**Applications**:
- Repository clone failures → show URL, check auth, verify access
- Missing configuration files → show examples, link to docs
- Environment setup failures → suggest validation commands, debugging steps

This pattern significantly improves user experience by reducing the time from error to resolution. Users get actionable information immediately rather than having to search documentation or logs.

### Bash Completion Implementation

**Learning**: Shell completion is a critical UX feature for CLI tools that significantly improves usability and discoverability.

**Problem**: Users expect modern CLI tools to support tab completion for commands, flags, and context-specific arguments (like container names). Without completion, users must memorize all commands and flags or constantly reference help text.

**Solution**: Implement comprehensive bash completion that provides:
1. Command completion at the top level
2. Flag completion based on current command context
3. Dynamic completion of container names from `devbox list`
4. Smart suggestions for common values (like tail line counts)
5. Context-aware completion (e.g., suggesting common commands after `devbox exec <container>`)

**Implementation Pattern**:
```bash
_devbox_completion() {
    local cur prev words cword
    _init_completion || return

    # Define top-level commands
    local commands="init create list attach stop start rm logs exec ports help"

    # Extract the current command being completed
    local command=""
    for ((i=1; i < cword; i++)); do
        if [[ "${words[i]}" != -* ]]; then
            command="${words[i]}"
            break
        fi
    done

    # If no command yet, complete command names
    if [[ -z "$command" ]]; then
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        return 0
    fi

    # Command-specific completion
    case "$command" in
        attach|stop|start|rm|logs|ports|exec)
            if [[ "$cur" == -* ]]; then
                # Complete flags for this command
                COMPREPLY=($(compgen -W "$flags" -- "$cur"))
            else
                # Complete container names from devbox list
                COMPREPLY=($(compgen -W "$(_devbox_containers)" -- "$cur"))
            fi
            ;;
    esac
}

# Helper to get container names dynamically
_devbox_containers() {
    devbox list 2>/dev/null | tail -n +3 | awk '{print $1}'
}

complete -F _devbox_completion devbox
```

**Key Insights**:
- Use `_init_completion` from bash-completion library for proper setup (with fallback for minimal environments)
- Parse `words` array to determine current command context
- Provide flag completion only when cursor is on a flag (`cur` starts with `-`)
- Dynamic completion (container names) should call the actual CLI command and parse output
- Suggest common values for option arguments (e.g., `10 50 100` for `--tail`)
- For commands that take variable arguments (like `exec`), suggest common commands but allow arbitrary input
- Context-aware completion improves UX (e.g., after `devbox exec container`, suggest `bash`, `sh`, `gh`, `claude`)

**Testing Strategy**:
```bash
# Test completion by simulating COMP_WORDS and calling completion function
COMP_WORDS=("devbox" "init" "")
COMP_CWORD=2
COMPREPLY=()
_devbox_completion

# Verify expected completions are present
for flag in "--bedrock" "--import-aws"; do
    # Check if flag is in COMPREPLY array
done
```

**Test Coverage**:
- Top-level command completion
- Flag completion for each command
- Container name completion for commands that need it
- Value suggestions for options like `--tail`
- Context-specific suggestions (exec command suggestions)
- Edge cases like `rm -a` (should not suggest container names)

**Key Insights for Testing**:
- Test completion by setting `COMP_WORDS`, `COMP_CWORD`, and calling the completion function directly
- Verify presence of expected completions in `COMPREPLY` array
- Test both flag completion (`cur` starts with `-`) and argument completion
- Use `|| true` pattern to prevent test failures from stopping the suite when not using `set -e`
- Comprehensive completion tests ensure all commands, flags, and contexts are covered

**Installation**:
Users should be able to:
1. Source the completion file directly: `source completions/devbox.bash`
2. Install system-wide: Copy to `/etc/bash_completion.d/` or `~/.local/share/bash-completion/completions/`
3. Add to shell profile: `echo "source /path/to/devbox.bash" >> ~/.bashrc`

**Benefits**:
- Significantly improves discoverability (users find commands and flags via tab)
- Reduces typing (complete long flag names with tab)
- Prevents errors (completion shows valid options)
- Professional polish expected of production CLI tools
- Dynamic container name completion makes operations faster

This implementation demonstrates that shell completion should be considered early in CLI development, not as an afterthought. It's a high-value feature that dramatically improves daily usage.

### Bash Completion Portability

**Learning**: Bash completion scripts must work in environments without the bash-completion package installed.

**Problem**: Many completion scripts depend on `_init_completion` from the bash-completion package. When this package isn't installed or sourced, completions silently fail with cryptic errors like "_init_completion: command not found".

**Root Cause**: The `_init_completion` function is provided by the bash-completion package (`/usr/share/bash-completion/bash_completion`) which:
- May not be installed on all systems
- Might not be sourced in all shell configurations
- Is often missing in minimal environments (containers, CI/CD)

**Solution**: Provide a fallback implementation for environments without bash-completion:

```bash
# Fallback _init_completion for systems without bash-completion package
if ! declare -F _init_completion >/dev/null 2>&1; then
    _init_completion() {
        # Basic implementation when bash-completion is not available
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
    }
fi

_devbox_completion() {
    local cur prev words cword
    _init_completion || return

    # ... rest of completion logic
}
```

**Key Insights**:
1. **Check for existence**: Use `declare -F _init_completion` to detect if the function exists
2. **Minimal fallback**: The fallback only needs to set up the basic variables (`cur`, `prev`, `words`, `cword`)
3. **Let advanced features fail gracefully**: bash-completion provides advanced features (like handling special chars), but basic completion works fine without them
4. **Test without bash-completion**: Always test in a clean environment (`bash --norc --noprofile`)

**Testing Strategy**:
```bash
# Test in environment without bash-completion
bash --norc --noprofile -c "
    source completions/devbox.bash

    # Simulate tab completion
    COMP_WORDS=(devbox '')
    COMP_CWORD=1
    _devbox_completion

    # Verify completions work
    echo \${COMPREPLY[*]}
"
```

**Benefits**:
- Completion works everywhere (servers, minimal containers, fresh installs)
- No confusing silent failures when bash-completion isn't available
- Users don't need to install extra packages
- Still uses bash-completion features when available (better handling of edge cases)

**Common Mistake to Avoid**:
Don't just blindly require bash-completion. Many "completion not working" issues stem from this assumption. A simple fallback makes your completion portable and reliable.

### Installation Script Design

**Learning**: A well-designed installation script significantly improves user adoption by making setup effortless.

**Problem**: CLI tools often require multiple manual steps to install: copying binaries, setting permissions, installing completion files, and building Docker images. Users may forget steps or do them incorrectly.

**Solution**: Create a comprehensive installation script that handles all setup with sensible defaults and useful options.

**Key Features Implemented**:
```bash
# Basic installation (system-wide)
sudo ./install.sh

# User installation (no sudo required)
./install.sh --prefix ~/.local

# Preview what would be installed
./install.sh --dry-run

# Uninstall when needed
./install.sh --prefix ~/.local --uninstall

# Skip optional components
./install.sh --skip-image --skip-completion
```

**Implementation Pattern**:
```bash
#!/bin/bash
set -euo pipefail

# Default configuration
DEFAULT_PREFIX="/usr/local"
PREFIX="${PREFIX:-$DEFAULT_PREFIX}"
DRY_RUN=false
UNINSTALL=false
SKIP_IMAGE=false
SKIP_COMPLETION=false

# Logging functions for consistent output
log_info() { echo -e "${BLUE}INFO:${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

# Execute or show command based on dry-run mode
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "  Would run: $*"
    else
        eval "$*"
    fi
}

# Installation functions
install_binary() {
    mkdir -p "$PREFIX/bin"
    cp "$SCRIPT_DIR/bin/devbox" "$PREFIX/bin/devbox"
    chmod +x "$PREFIX/bin/devbox"
}

install_completion() {
    mkdir -p "$PREFIX/share/bash-completion/completions"
    cp "$SCRIPT_DIR/completions/devbox.bash" "$PREFIX/share/bash-completion/completions/devbox"
}
```

**Key Insights**:
1. **Prefix flexibility**: Support custom installation directories via `--prefix` for user-level installs without sudo
2. **Dry-run mode**: Essential for testing and previewing changes before executing
3. **Uninstall capability**: Users need a clean way to remove the software
4. **Skip options**: Allow skipping optional components (Docker image, completions) for faster installs or constrained environments
5. **Environment variable fallback**: Support `PREFIX` env var in addition to `--prefix` flag
6. **PATH warnings**: Detect when install directory is not in PATH and provide instructions
7. **Post-install guidance**: Show users how to enable completion and finish setup

**Testing Strategy for Installation Scripts**:
```bash
test_install_to_temp_dir() {
    local test_prefix="/tmp/devbox-install-test-$$"

    # Install to temporary directory
    ./install.sh --prefix "$test_prefix" --skip-image

    # Verify binary exists and works
    [[ -x "$test_prefix/bin/devbox" ]]
    "$test_prefix/bin/devbox" --help >/dev/null

    # Verify completion was installed
    [[ -f "$test_prefix/share/bash-completion/completions/devbox" ]]

    # Clean up
    rm -rf "$test_prefix"
}

test_uninstall() {
    # Install first
    ./install.sh --prefix "$test_prefix" --skip-image

    # Then uninstall
    ./install.sh --prefix "$test_prefix" --uninstall

    # Verify files are gone
    [[ ! -f "$test_prefix/bin/devbox" ]]
}
```

**Key Insights for Testing**:
- Use unique temporary directories with `$$` (PID) to avoid conflicts
- Test both install and uninstall flows
- Verify the installed binary actually works (not just exists)
- Use `--skip-image` in tests to avoid slow Docker builds
- Clean up test directories even on failure

**Benefits of This Approach**:
- Single command to install everything
- Works for both system-wide and user installations
- Idempotent (can run multiple times safely)
- Self-documenting via `--help`
- Easy to test with `--dry-run`
- Clean removal with `--uninstall`

This pattern makes the difference between "download and run a dozen commands" and "download and run one command" - a major UX improvement.

## Lessons for Future Agent Development

1. **Start with structure, then functionality** - CLI scaffolding paid dividends
2. **Test early and often** - Unit tests caught edge cases in argument handling
3. **Plan for user experience** - Color coding and clear error messages matter
4. **Document decisions** - Architecture choices need rationale for future reference
5. **Incremental validation** - Each phase should have working, testable output
6. **Follow TDD rigorously** - Write tests first, implement to pass, refactor if needed
7. **Reuse patterns** - Consistent command structure makes codebase predictable and maintainable
8. **Handle variable arguments carefully** - Commands that take arbitrary user input need special parsing and quoting logic
9. **Understand Docker behavior deeply** - Different commands behave differently based on container state; use `docker inspect` for reliable state-independent queries
10. **Design tests for real environments** - Tests should handle resource conflicts, partial cleanup, and idempotent execution
11. **Provide comprehensive error messages** - Container entrypoints and critical operations should give users actionable, contextual error information with clear remediation steps
12. **Make installation effortless** - A single installation script with sensible defaults, `--dry-run`, `--uninstall`, and `--prefix` options reduces adoption friction significantly
13. **Make bash completion portable** - Always provide fallback for `_init_completion` to work without bash-completion package; test in minimal environments (`bash --norc --noprofile`)
14. **Design secrets management for security** - Never prompt for secrets interactively (accidental exposure risk); use `--from-env` or `--from-file` patterns; always restrict file permissions (600/700); never display secret values in output
15. **Commands that don't need Docker should skip Docker checks** - Handle early dispatch in main() before Docker checks to enable purely local operations (like secrets management) to work without Docker running
16. **Exit codes must be captured correctly in tests** - When using `|| true` to prevent test failures, the exit code is overwritten; use `set +e`, capture exit code to variable, then `set -e` to properly test expected failures
17. **Run integration tests after major changes** - Run `tests/test_checkpoint3_integration.sh` after significant changes to CLI commands, Dockerfile, init, or entrypoint scripts. Requires `expect` package and either existing `devbox-github-token` secret or `GITHUB_TOKEN` env var
18. **Secure container secret injection via Docker volumes** - Never pass secrets as environment variables (visible in `docker inspect`); use Docker volumes mounted to `/run/secrets/` instead. Create a dedicated secrets volume per container (`<container>-secrets`), populate it via a setup container running as root to ensure correct ownership for the devbox user inside the container. Use base64 encoding when passing secret values through shell commands to handle special characters safely. Clean up secrets volumes when containers are removed. Bind mounts from host filesystem don't work well with rootless Docker due to user namespace mapping causing permission issues.
19. **Bash arithmetic with `set -e` needs `|| true`** - The `((count++))` expression returns the OLD value before incrementing. When `count=0`, `((count++))` returns 0 (falsy), causing bash to exit with `set -e`. Always use `((count++)) || true` in scripts with `set -e` to prevent unexpected exits in loops.
20. **Destructive operations should require confirmation** - Add confirmation prompts for irreversible operations like `rm`. Use `--force` flag to skip confirmation for automation/scripting. Show what will be affected before prompting. Test both confirmation paths (accept and decline).
21. **Implement migration commands for breaking changes** - When deprecating features (like env var auth in favor of secrets), provide: (1) Deprecation warnings with clear migration instructions, (2) Helper commands (`import-env`) that automate the migration, (3) Security context explaining why the new approach is better. Show warnings at the point of use (e.g., during `create` when using deprecated env var), not just in documentation.
22. **Indirect variable access in bash uses `${!varname}`** - To read the value of a variable whose name is stored in another variable, use indirect expansion: `value="${!env_var}"`. This is essential for commands that take variable names as arguments (like `import-env`).
23. **Make optional features degrade gracefully** - Rather than failing when optional configurations are missing, provide sensible defaults. For example, if a Nix flake.nix isn't present, drop into a basic bash shell with base tools instead of erroring out. This removes barriers to adoption - users can start using the tool immediately and add configurations later as needed.
24. **Progress indicators for long operations** - Implement spinner animations for long-running operations (Docker builds, volume setup, container creation) to provide visual feedback. Use an include guard (`_DEVBOX_PROGRESS_LOADED`) to prevent errors when sourcing the library multiple times. Support non-interactive mode via `DEVBOX_NO_SPINNER=1` or CI environment detection. Cleanup with traps to restore cursor visibility. The `with_spinner` wrapper runs commands with a spinner and returns the command's exit code.
25. **Use Docker-in-Docker with minimal capabilities** - Never mount the host Docker socket (`-v /var/run/docker.sock:/var/run/docker.sock`) into containers. Mounting the host socket allows container escape via `docker run -v /:/host ubuntu cat /host/etc/passwd`. Instead, use Docker-in-Docker (DinD) with minimal capabilities: `--cap-add=SYS_ADMIN --cap-add=NET_ADMIN --cap-add=MKNOD` plus `--security-opt seccomp=unconfined --security-opt apparmor=unconfined --cgroupns=private`. Avoid `--privileged` as it grants all capabilities unnecessarily.
26. **Make privileged features opt-in** - Docker access and sudo should be disabled by default to reduce attack surface. Add explicit flags (`--enable-docker`, `--sudo`) to enable these features when needed. This follows the principle of least privilege and makes security-conscious defaults the norm.
27. **Configure sudo at runtime via setup containers** - Instead of baking sudo configuration into the Dockerfile (which would always enable it), use the setup container pattern: run a temporary container as root to configure sudoers, then mount the config into the main container. This allows per-container customization: `--sudo nopass` (passwordless), `--sudo password` (with password hash).
28. **Never expose Docker daemon on TCP** - When running Docker-in-Docker, only listen on the Unix socket (`--host=unix:///var/run/docker.sock`), never on TCP (`--host=tcp://0.0.0.0:2375`). TCP exposure allows network-based attacks and is rarely needed for development workflows.
29. **Use SHA-512 for password hashing** - When collecting passwords at container creation time (e.g., for sudo), hash them immediately using `openssl passwd -6` and clear the plaintext from memory. Pass only the hash to the container, where `chpasswd -e` can apply it. Never log or display passwords or hashes.
30. **Prefer token-based over interactive OAuth flows in containers** - Running OAuth flows (browser redirects) inside containers is unreliable. Instead, have users run authentication tools (`claude setup-token`) on the host and store the resulting token as a secret. This separation of concerns (auth on host, token in container) is more robust and works across different environments. Set environment variables at runtime inside the entrypoint rather than via docker env vars to keep tokens out of `docker inspect` output.
31. **Use explicit flag names for required parameters** - When a command requires multiple secrets or credentials, use explicit flag names (`--github-secret`, `--claude-code-secret`) rather than generic repeatable flags (`--secret`). This makes validation rules clearer (e.g., "GitHub secret is required", "Claude secret required for non-Bedrock mode") and improves discoverability via help text and bash completion.
32. **Default to secure-by-default for network egress** - Container network access should be restricted by default, not permissive. Use security profiles (`standard`, `strict`, `airgapped`) with sensible defaults that allow common development workflows (package managers, git hosts, cloud APIs) while blocking known exfiltration vectors. Store profile configuration in separate files (`profiles/*.conf`) for easy customization. Provide escape hatch (`--egress permissive`) for users who need unrestricted access.
33. **Design network controls with multiple enforcement layers** - Effective egress control requires multiple mechanisms: (1) Custom Docker networks for isolation, (2) DNS proxy sidecars for domain-level filtering, (3) iptables rules for IP/port filtering. Each layer addresses different attack vectors. The hybrid approach provides defense in depth while remaining practical to implement.
34. **Store container configuration in labels** - Use Docker container labels (`devbox.egress`, `devbox.mode`, etc.) to persist configuration that needs to survive container restarts. This enables features like `devbox list` showing egress profiles and `devbox network show` displaying current rules. Labels are queryable via `docker inspect` and can be updated with `docker container update --label-add`.
35. **Implement network enforcement incrementally** - Start with the simplest enforcement mechanism first (airgapped mode uses Docker's built-in `--network none`). This provides immediate value with minimal code changes. More complex mechanisms (DNS filtering, iptables rules) can be deferred. The key insight is that profile configuration and enforcement are separate concerns - you can have robust configuration parsing/display without enforcement, then add enforcement layer by layer. Always write integration tests that verify actual enforcement, not just configuration parsing.
36. **DNS proxy sidecar for domain filtering** - Use dnsmasq in a sidecar container to filter DNS requests. Block domains by returning NXDOMAIN via `address=/domain/#` syntax. Create a custom Docker network, start the DNS proxy first, get its IP, then start the main container with `--network <network> --dns <proxy-ip>`. The proxy forwards allowed queries to upstream DNS (8.8.8.8, 1.1.1.1) and blocks configured domains. Wait for the proxy to get an IP before starting dependent containers (poll with timeout). Clean up both the DNS container and network when removing the main container.
37. **Handle kernel module limitations gracefully** - Docker's `--opt "com.docker.network.bridge.enable_icc=false"` requires the `br_netfilter` kernel module. On systems without it (some containers, minimal VMs), network creation fails. Implement a fallback: try with ICC restriction first, fall back to standard bridge network if it fails. This ensures the feature works across different environments while providing better isolation where available.
38. **DNS allowlist vs blocklist mode in dnsmasq** - dnsmasq supports two filtering modes: (1) Blocklist mode (`DEFAULT_ACTION=accept`): allow all domains, block specific ones with `address=/blocked.com/#` (returns NXDOMAIN). (2) Allowlist mode (`DEFAULT_ACTION=drop`): block all domains by default with `address=/#/`, then explicitly allow specific domains with `server=/allowed.com/8.8.8.8` (forwards only those queries to upstream). The allowlist mode is critical for strict security profiles where only explicitly whitelisted domains should resolve. Test both modes: verify blocked domains return NXDOMAIN/no answer, and allowed domains resolve successfully. Case-insensitive matching is important for DNS test assertions (nslookup returns "Can't find" not "can't find").
