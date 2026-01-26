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

## Implementation Progress Update

### Completed: `devbox init` Command ✅

**Status**: Complete with comprehensive testing and documentation

**Implementation Highlights**:
- Full flag parsing (`--bedrock`, `--import-aws`, `--dry-run`, `--help`)
- Interactive Docker volume management with user confirmation prompts
- Environment variable passing to init containers for mode configuration
- Host credential mounting for AWS import functionality
- Comprehensive error handling and user feedback
- Complete help documentation with examples

**Testing Strategy**:
- Created dedicated `test_init.sh` with 7 comprehensive tests covering:
  - Help text validation
  - Flag parsing (single and multiple flags)
  - Error handling for invalid flags
  - Docker volume operations
  - Dry-run mode for safe testing
- Updated existing `test_cli_basic.sh` to account for implemented functionality
- All tests pass with proper cleanup and teardown

**Key Technical Learnings**:
- **User confirmation prompts** prevent accidental credential overwrites in CLIs
- **Dry-run flags** are essential for testing commands with side effects
- **Comprehensive flag parsing** with clear error messages improves user experience
- **Docker volume management** requires careful cleanup in test scenarios
- **Environment variable forwarding** to containers enables flexible configuration

### Completed: `devbox list` Command ✅

**Status**: Complete with comprehensive testing and documentation

**Implementation Highlights**:
- Docker container enumeration using `docker ps -a` with name filters
- Container label extraction for metadata (repo, mode, ports)
- Formatted table output with proper column alignment using `printf`
- Robust container name resolution supporting both test and production prefixes
- Comprehensive flag parsing and help text
- Graceful handling of containers without metadata labels

**Testing Strategy**:
- Created dedicated `test_list.sh` with 7 comprehensive tests covering:
  - Help text validation and flag parsing
  - Empty container list handling
  - Single and multiple container display
  - Table header formatting validation
  - Non-devbox container filtering
  - Error handling for invalid flags
- Isolated test environment using Alpine base image to avoid entrypoint conflicts
- Proper cleanup with container tracking and teardown

**Key Technical Learnings**:
- **Container metadata strategy**: Using Docker labels is effective for storing container configuration (repo URL, auth mode, port mappings)
- **Test isolation**: Using lightweight Alpine images for tests avoids complex entrypoint issues with custom base images
- **Table formatting**: `printf` with field widths provides consistent output formatting across variable-length data
- **Prefix handling**: Flexible name extraction logic handles both production (`devbox-`) and test (`devbox-test-`) container prefixes
- **Status parsing**: Docker status strings require parsing to extract simple "running/exited" states
- **Graceful degradation**: Missing or malformed container labels should default to sensible values rather than breaking output

**Technical Patterns Established**:
- Container enumeration pattern that will be reused by other commands (`attach`, `stop`, `start`, `rm`)
- Label-based metadata storage convention for devbox containers
- Consistent table output formatting approach
- Test container management patterns for integration testing

### Completed: `devbox create` Command ✅

**Status**: Complete with comprehensive testing and full functionality

**Implementation Highlights**:
- Complex argument and flag parsing supporting positional args and repeatable flags (`--port`)
- Comprehensive Docker command generation with all required environment variables
- Container name conflict detection across both production and test prefixes
- Metadata storage using Docker labels for persistence across container lifecycles
- Dry-run mode for safe testing and validation
- Robust authentication mode support (OAuth vs Bedrock) with appropriate environment configuration
- Workspace volume creation for persistent project storage

**Testing Strategy**:
- Created dedicated `test_create.sh` with 9 comprehensive tests covering:
  - Help text validation with all flags documented
  - Required argument validation (name and repository URL)
  - Invalid flag rejection with proper error messages
  - Basic container creation in dry-run mode
  - Multiple port mapping handling
  - Bedrock authentication mode configuration
  - Container name conflict detection and prevention
  - Complex multi-flag combinations
- Dry-run testing pattern enables safe validation of Docker commands without side effects
- Container tracking and cleanup for integration tests

**Key Technical Learnings**:
- **Complex flag parsing**: Bash arrays for repeatable flags (`ports=()`) with proper validation
- **Docker command construction**: String building approach allows flexible, readable command generation
- **Environment variable forwarding**: Careful handling of authentication modes (OAuth vs Bedrock) with appropriate env vars
- **Container name validation**: Essential to check both production and test prefixes to prevent conflicts
- **Dry-run patterns**: `--dry-run` flags enable comprehensive testing without side effects
- **Metadata persistence**: Docker labels provide reliable storage for container configuration that survives container lifecycle
- **Workspace volumes**: Named volumes (`${container_name}-workspace`) provide persistent project storage

**Advanced Bash Patterns Established**:
- **Repeatable flag handling**: `ports+=("$2")` pattern for accumulating multiple values
- **Conditional string building**: Environment variables and Docker args constructed conditionally based on flags
- **Array-to-string conversion**: `IFS=,; echo "${ports[*]}"` for comma-separated label values
- **Command validation**: Pre-execution validation (credential volume exists, name conflicts) prevents partial failures
- **Test-aware implementations**: Code that handles both production and test environment prefixes

### Completed: `devbox attach` Command ✅

**Status**: Complete with comprehensive testing and full functionality

**Implementation Highlights**:
- Robust container name resolution supporting both production (`devbox-`) and test (`devbox-test-`) prefixes
- Container state validation ensuring only running containers can be attached to
- Comprehensive flag parsing with help text and error handling
- Dry-run mode for safe testing of attach logic without actual attachment
- Clean display name extraction for user-friendly output
- Proper Docker attach integration with user guidance on detach sequence

**Testing Strategy**:
- Created dedicated `test_attach.sh` with 8 comprehensive tests covering:
  - Help text validation and flag parsing
  - Missing argument handling
  - Invalid flag rejection
  - Nonexistent container error handling
  - Stopped container state validation
  - Dry-run mode functionality
  - Container ID resolution (both name and partial ID)
  - Extra argument rejection
- All tests pass with proper container lifecycle management
- Test isolation using temporary containers with cleanup

**Key Technical Learnings**:
- **Container Resolution Pattern**: Updated `resolve_container()` function to handle both production and test prefixes, establishing a pattern for other lifecycle commands
- **State Validation**: Docker container state checking (`docker inspect --format '{{.State.Status}}'`) is essential for attach operations
- **Dual-Prefix Support**: CLI tools that support both production and testing environments need careful prefix handling throughout
- **Dry-Run Testing**: Mock Docker operations enable comprehensive testing without side effects
- **User Experience**: Clear messaging about detach sequences (Ctrl+P, Ctrl+Q) improves user experience
- **Test Safety**: Never clean up production containers in test suites - only test-prefixed containers should be touched

**Container Lifecycle Foundation**:
- Established pattern for container name resolution that will be reused by `stop`, `start`, `rm` commands
- Demonstrated state validation approach for other commands that require specific container states
- Created test patterns for Docker integration testing with proper cleanup

**Critical Safety Learning**:
- Test suites must NEVER delete production containers - only test-prefixed containers should be cleaned up during testing
- Container resolution logic must handle both production and test environments safely

### Completed: `devbox stop` Command ✅

**Status**: Complete with comprehensive testing and full functionality

**Implementation Highlights**:
- Robust container name and ID resolution using established patterns from `attach` command
- Graceful handling of already stopped containers with appropriate user feedback
- Comprehensive flag parsing with help text, dry-run mode, and error handling
- Container state validation to provide informative messages to users
- Clean implementation following established CLI patterns and conventions

**Testing Strategy**:
- Created dedicated `test_stop.sh` with 8 comprehensive tests covering:
  - Help text validation and flag parsing
  - Missing argument handling with proper error messages
  - Nonexistent container error handling
  - Running container stop functionality
  - Already stopped container graceful handling
  - Container ID resolution (both name and partial ID)
  - Dry-run mode for safe testing
  - Extra arguments rejection
- All tests pass with proper container lifecycle management and cleanup
- Enhanced test helper function to create truly stopped containers for accurate testing

**Key Technical Learnings**:
- **Container State Management**: Checking container status before operations provides better user experience
- **Graceful State Handling**: Commands should handle edge cases (already stopped containers) elegantly without errors
- **Test Container Creation**: Creating stopped containers for testing requires starting and then stopping, not just using `docker create`
- **Pattern Consistency**: Following established patterns from similar commands (like `attach`) accelerates development and ensures consistency
- **Case-Sensitive String Matching**: Test pattern matching must account for exact case ("USAGE:" vs "Usage:")
- **Dry-Run Testing**: Enables comprehensive testing of Docker operations without side effects

**Development Patterns Reinforced**:
- Container resolution pattern now used across multiple commands (`attach`, `stop`)
- Consistent flag parsing and help text structure across all commands
- Comprehensive test coverage with proper setup/teardown for Docker integration testing
- Pre-commit hook integration for automated test validation
- Error message consistency and user-friendly feedback patterns

**Critical Debugging Insights**:
- **Array Handling in Bash**: Proper initialization with `declare -a` prevents "unbound variable" errors
- **Container Cleanup**: Test failures can leave containers behind, requiring robust cleanup mechanisms
- **Status Checking**: Docker container states ("created", "running", "exited") must be understood for proper command behavior
- **Pattern Matching**: Debugging failed tests often reveals case-sensitivity or exact string matching issues

## Next Priority Tasks

Based on current progress with init, list, create, attach, and stop completed, the next highest-leverage tasks are:

1. **Implement remaining container lifecycle commands** - `start`, `rm` to complete basic container management
2. **Add end-to-end authentication testing** - Validate full init→create→attach flow with real repositories
3. **Implement additional commands** - `logs`, `exec`, `ports` for enhanced container management
4. **End-to-end workflow validation** - Test complete development workflow with real repositories

## Lessons for Future Agent Development

1. **Start with structure, then functionality** - CLI scaffolding paid dividends
2. **Test early and often** - Unit tests caught edge cases in argument handling
3. **Plan for user experience** - Color coding and clear error messages matter
4. **Document decisions** - Architecture choices need rationale for future reference
5. **Incremental validation** - Each phase should have working, testable output