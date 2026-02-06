# CLI Command Patterns

Detailed patterns for implementing CLI commands in this project.

## Command Structure

Every command follows this flow:
1. Flag parsing loop with `while [[ $# -gt 0 ]]`
2. Help check (`--help`/`-h`) before any validation
3. Argument validation after all flags parsed
4. Container resolution via `resolve_container()`
5. Command execution (with optional `--dry-run`)

```bash
cmd_example() {
    local container_name=""
    local some_flag=false
    local dry_run=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --flag|-f) some_flag=true; shift ;;
            --help|-h) show_help; return 0 ;;
            --dry-run) dry_run=true; shift ;;
            --*) log_error "Unknown option: $1"; return 1 ;;
            *) container_name="$1"; shift ;;
        esac
    done

    [[ -z "$container_name" ]] && log_error "Container required" && return 1
    container_id=$(resolve_container "$container_name") || return 1

    # Execute
    docker_cmd="docker ..."
    [[ "$dry_run" == true ]] && echo "$docker_cmd" && return 0
    eval "$docker_cmd"
}
```

## Bash Script Structure

```bash
#!/bin/bash
set -euo pipefail

# Constants at top
readonly DEVBOX_IMAGE="devbox-base:latest"
readonly CONTAINER_PREFIX="devbox-"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}INFO:${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

# Validation helpers
check_docker() { ... }
ensure_image() { ... }
resolve_container() { ... }

# Command implementations
cmd_create() { ... }
cmd_list() { ... }

# Main dispatcher
main() {
    case "$1" in
        create) shift; cmd_create "$@" ;;
        list) shift; cmd_list "$@" ;;
        *) log_error "Unknown command: $1" ;;
    esac
}

main "$@"
```

## Variable-Length Arguments

For commands like `exec` that take arbitrary user commands:

```bash
cmd_exec() {
    local container_name=""
    local exec_command=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -it|-ti) interactive_flags="-it"; shift ;;
            --help|-h) show_help; return 0 ;;
            *)
                if [[ -z "$container_name" ]]; then
                    container_name="$1"
                    shift
                else
                    exec_command+=("$@")
                    break  # Preserve all remaining args
                fi
                ;;
        esac
    done

    # Quote args with spaces
    for arg in "${exec_command[@]}"; do
        if [[ "$arg" =~ [[:space:]] ]]; then
            docker_cmd="$docker_cmd \"$arg\""
        else
            docker_cmd="$docker_cmd $arg"
        fi
    done
}
```

Key points:
- Use `"$@"` to capture remaining args
- Use `break` after capturing to preserve them
- Store in array for flexibility
- Quote args containing spaces

## Error Handling

- Errors go to stderr: `log_error "message" >&2`
- Unknown commands show error AND help text
- Exit codes: 0 = success, 1 = error
- Check `docker info` before Docker operations

## Commands Without Docker

Some commands (like `secrets`) don't need Docker. Dispatch early in `main()` before `check_docker()`:

```bash
main() {
    case "$1" in
        secrets) shift; cmd_secrets "$@"; return ;;  # Early return
        help|-h|--help) show_help; return ;;
    esac

    check_docker || exit 1  # Docker check after early dispatch
    # ... rest of commands
}
```
