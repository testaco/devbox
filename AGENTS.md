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
2. **Integration tests**: Docker daemon interaction (planned)
3. **End-to-end tests**: Full workflow testing (planned)

**Key Insights**:
- Start with unit tests for quick feedback
- Mock external dependencies where possible
- Plan for testing in different environments (with/without Docker)

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

## Next Priority Tasks

Based on current progress, the next highest-leverage tasks are:

1. **Implement `devbox init`** - Enables credential setup, unblocking all other functionality
2. **Implement `devbox list`** - Simple command that validates Docker integration
3. **Implement `devbox create`** - Core functionality for container creation
4. **Add integration tests** - Validate Docker interactions work correctly

## Lessons for Future Agent Development

1. **Start with structure, then functionality** - CLI scaffolding paid dividends
2. **Test early and often** - Unit tests caught edge cases in argument handling
3. **Plan for user experience** - Color coding and clear error messages matter
4. **Document decisions** - Architecture choices need rationale for future reference
5. **Incremental validation** - Each phase should have working, testable output