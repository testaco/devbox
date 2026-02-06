# Bash Scripting Patterns

Bash-specific patterns and gotchas.

## Arithmetic with `set -e`

The `((count++))` expression returns the OLD value before incrementing. When `count=0`, it returns 0 (falsy), causing exit with `set -e`:

```bash
# WRONG - exits when count=0
set -e
count=0
((count++))  # Returns 0, script exits!

# RIGHT
((count++)) || true
```

## Indirect Variable Access

Read a variable whose name is in another variable:

```bash
env_var="GITHUB_TOKEN"
value="${!env_var}"  # Gets value of $GITHUB_TOKEN
```

Essential for commands that take variable names as arguments.

## Bash Completion

### Basic Structure

```bash
_devbox_completion() {
    local cur prev words cword
    _init_completion || return

    local commands="init create list attach stop start rm logs exec"

    # Find current command
    local command=""
    for ((i=1; i < cword; i++)); do
        if [[ "${words[i]}" != -* ]]; then
            command="${words[i]}"
            break
        fi
    done

    # Complete commands or command-specific args
    if [[ -z "$command" ]]; then
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
    else
        case "$command" in
            attach|stop|start|rm)
                COMPREPLY=($(compgen -W "$(_devbox_containers)" -- "$cur"))
                ;;
        esac
    fi
}

_devbox_containers() {
    devbox list 2>/dev/null | tail -n +3 | awk '{print $1}'
}

complete -F _devbox_completion devbox
```

### Portability Fallback

`_init_completion` comes from bash-completion package, which may not be installed:

```bash
# Fallback for systems without bash-completion
if ! declare -F _init_completion >/dev/null 2>&1; then
    _init_completion() {
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        prev="${COMP_WORDS[COMP_CWORD-1]}"
        words=("${COMP_WORDS[@]}")
        cword=$COMP_CWORD
    }
fi
```

Test in clean environment:
```bash
bash --norc --noprofile -c "source completions/devbox.bash; ..."
```

### Testing Completion

```bash
COMP_WORDS=("devbox" "init" "")
COMP_CWORD=2
COMPREPLY=()
_devbox_completion

# Check results
for flag in "--bedrock" "--import-aws"; do
    # Verify in COMPREPLY
done
```

## String Quoting

When building shell commands dynamically:

```bash
for arg in "${exec_command[@]}"; do
    if [[ "$arg" =~ [[:space:]] ]]; then
        docker_cmd="$docker_cmd \"$arg\""
    else
        docker_cmd="$docker_cmd $arg"
    fi
done

eval "$docker_cmd"  # Use eval carefully
```

## Color Output

```bash
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'  # No Color

log_error() { echo -e "${RED}✗${NC} $*" >&2; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
```
