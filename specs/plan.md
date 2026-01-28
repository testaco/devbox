# Devbox Implementation Plan

## Phase 1: Foundation

### Docker Image
- [x] Create `docker/Dockerfile` with Debian bookworm-slim base
- [x] Install system dependencies (curl, git, ca-certificates, xz-utils, sudo)
- [x] Install Nix via Determinate Systems installer (`--init none --no-confirm`)
- [x] Install GitHub CLI from official apt repo
- [x] Install Node.js 20.x from NodeSource
- [x] Install Claude Code via npm (`@anthropic-ai/claude-code`)
- [x] Create non-root `devbox` user
- [x] Test image builds on arm64 (tested successfully on Apple Silicon)

### Entrypoint Script
- [x] Create `docker/entrypoint.sh`
- [x] Read `DEVBOX_REPO_URL` env var
- [x] Clone repo to `/workspace` if not present
- [x] Check for `flake.nix` or `shell.nix`, exit with error if missing
- [x] Enter Nix shell (`nix develop` or `nix-shell`)
- [x] Ensure shell stays open for attach (exec bash)

### Credential Volume
- [x] Define volume structure: `gh/`, `claude/`, `aws/`
- [x] Create init container script that mounts volume read-write
- [x] Verify `GH_CONFIG_DIR` env var works for GitHub CLI
- [x] Verify `CLAUDE_CONFIG_DIR` env var works for Claude Code (or find correct var)
- [x] Verify `AWS_CONFIG_FILE` and `AWS_SHARED_CREDENTIALS_FILE` work
- [x] Test read-only mount in work containers

---

## Phase 2: CLI Core

### Script Setup
- [x] Create `bin/devbox` bash script
- [x] Add shebang and strict mode (`set -euo pipefail`)
- [x] Define constants (image name, volume name, container prefix)
- [x] Add usage/help function
- [x] Add command dispatcher (case statement)
- [x] Add colored output and logging functions
- [x] Add Docker daemon check
- [x] Add base image building
- [x] Add container name resolution helper
- [x] Create unit tests for basic functionality

### Test Infrastructure & Pre-commit Hooks
- [x] Create comprehensive test suite (`tests/test_cli_basic.sh`, `tests/test_init.sh`, `tests/test_list.sh`, `tests/test_create.sh`)
- [x] Move `PROMPT` to `PROMPT.md` and ensure it's committed
- [x] Setup pre-commit hook that runs all tests
  - [x] Create `.git/hooks/pre-commit` script that:
    - [x] Changes to repository root directory
    - [x] Runs `tests/test_cli_basic.sh` with colored output
    - [x] Runs `tests/test_init.sh` with colored output
    - [x] Runs `tests/test_list.sh` with colored output
    - [x] Runs `tests/test_create.sh` with colored output
    - [x] Tracks overall success/failure across all test suites
    - [x] Provides clear success/failure messages
    - [x] Exits with code 1 (abort commit) if any tests fail
    - [x] Exits with code 0 (allow commit) if all tests pass
  - [x] Make hook executable (`chmod +x .git/hooks/pre-commit`)
  - [x] Test hook by making a test commit
  - [x] Fix test counting logic to properly handle skipped tests
  - [x] Add instructions in README for hook setup on new clones

### `devbox init`
- [x] Check if credentials volume exists, create if not
- [x] Parse `--bedrock` flag
- [x] Parse `--import-aws` flag
- [x] Run ephemeral init container with volume mounted rw
- [x] Run `gh auth login --web` inside container
- [x] If not `--bedrock`: run `claude` to trigger OAuth
- [x] If `--import-aws`: copy host `~/.aws/*` into volume
- [x] Print success message with mode (oauth/bedrock)

### `devbox create <name> <repo>`
- [x] Parse `--port` flag (repeatable)
- [x] Parse `--bedrock` flag
- [x] Parse `--aws-profile` flag
- [x] Validate name doesn't already exist
- [x] Build docker run command with:
  - [x] Container name with prefix (`devbox-<name>`)
  - [x] Credential volume mount (read-only)
  - [x] Port mappings
  - [x] Environment variables (repo URL, AWS profile, bedrock flag)
  - [x] Detached mode with TTY (`-dit`)
- [x] Store metadata (repo, mode, ports) as container labels
- [x] Print success message

### `devbox list`
- [x] Query Docker for containers with devbox prefix
- [x] Extract labels (repo, mode, ports)
- [x] Format table output (NAME, ID, STATUS, REPO, PORTS, MODE)

### `devbox attach <name-or-id>`
- [x] Resolve name to container ID
- [x] Run `docker attach` with proper TTY settings
- [x] Handle Ctrl+P,Q detach sequence

### `devbox stop <name-or-id>`
- [x] Resolve name to container ID
- [x] Run `docker stop`
- [x] Handle already stopped containers gracefully
- [x] Comprehensive help text with examples
- [x] Full flag parsing (--help, --dry-run)
- [x] Complete test suite with 8 comprehensive tests

### `devbox start <name-or-id>`
- [x] Resolve name to container ID
- [x] Run `docker start`
- [x] Comprehensive help text with examples
- [x] Full flag parsing (--help, --dry-run)
- [x] Complete test suite with 9 comprehensive tests

### `devbox rm <name-or-id>`
- [x] Parse `--force` flag
- [x] Resolve name to container ID
- [x] Check if running (error unless --force)
- [x] Run `docker rm` (with `-f` if forced)
- [x] Comprehensive help text with examples
- [x] Full flag parsing (--help, --dry-run, --force)
- [x] Workspace volume cleanup (removes associated volumes)
- [x] Complete test suite with 10 comprehensive tests

---

## Phase 3: Polish

### Additional Commands
- [x] `devbox logs <name-or-id>` with `-f` follow flag
  - [x] Comprehensive help text with examples
  - [x] Full flag parsing (--help, --dry-run, -f/--follow, --tail)
  - [x] Works with both running and stopped containers
  - [x] Complete test suite with 11 comprehensive tests
- [x] `devbox exec <name-or-id> <command...>`
  - [x] Comprehensive help text with examples
  - [x] Full flag parsing (--help, --dry-run, -it for interactive)
  - [x] Variable-length command argument handling
  - [x] Proper quoting for arguments with spaces
  - [x] Only works with running containers (enforced)
  - [x] Complete test suite with 11 comprehensive tests
  - [x] Added to pre-commit hook
- [x] `devbox ports <name-or-id>`
  - [x] Comprehensive help text with examples
  - [x] Full flag parsing (--help, --dry-run)
  - [x] Works with both running and stopped containers
  - [x] Uses HostConfig.PortBindings for accurate port display
  - [x] Complete test suite with 11 comprehensive tests
  - [x] Added to pre-commit hook

### Error Handling
- [x] Check Docker daemon is running (implemented in `check_docker()`)
- [x] Check credentials volume exists before create (implemented in `cmd_create()`)
- [x] Friendly error if container name not found (implemented in `resolve_container()`)
- [x] Friendly error if repo clone fails (comprehensive error messages in `entrypoint.sh`)
- [x] Friendly error if no Nix config in repo (detailed instructions and examples in `entrypoint.sh`)
- [x] Friendly error if Nix shell entry fails (debugging tips in `entrypoint.sh`)

### UX Improvements
- [ ] Colored output (green success, red error, yellow warning)
- [ ] Progress indicators for long operations
- [ ] Confirm prompt for `rm` without `--force`

### Shell Completion
- [x] Create `completions/devbox.bash`
- [x] Complete commands
- [x] Complete container names for attach/stop/start/rm/logs/exec
- [x] Complete flags per command
- [x] Comprehensive test suite for all completion scenarios
- [x] Added to pre-commit hook

---

## Phase 4: Distribution

### Installation
- [x] Create `install.sh` script
  - [x] Supports `--prefix` for custom installation directory
  - [x] Supports `--dry-run` to preview actions
  - [x] Supports `--uninstall` to remove devbox
  - [x] Supports `--skip-image` to skip Docker build
  - [x] Supports `--skip-completion` to skip bash completion
  - [x] Comprehensive test suite (13 tests)
- [x] Copy `bin/devbox` to `/usr/local/bin` or `~/.local/bin`
- [x] Install bash completion to `<prefix>/share/bash-completion/completions/`
- [x] Build and tag Docker image (optional, via `--skip-image`)
- [ ] Push image to registry (optional: GitHub Container Registry)

### Documentation
- [x] Write README.md with installation instructions
- [x] Document all commands and flags (in help text and README)
- [ ] Add troubleshooting section
- [ ] Add example `flake.nix` for common stacks (Node, Python, Go)

---

## Validation Checkpoints

### Checkpoint 1: Image Works
- [x] Image builds successfully
- [x] Can run container manually with `docker run -it`
- [x] Nix shell works inside container (verified with proper profile sourcing)
- [x] `gh --version` works (v2.86.0)
- [x] `claude --version` works (v2.1.19)

### Checkpoint 2: Auth Works
- [x] Credential volume structure and permissions validated
- [x] Environment variables (GH_CONFIG_DIR, CLAUDE_CONFIG_DIR, AWS_*) working
- [x] Read-only credential mounting working
- [x] `devbox init` completes GitHub OAuth (CLI implemented)
- [x] `devbox init` completes Claude OAuth (non-bedrock) (CLI implemented)
- [x] `devbox init --bedrock` skips Claude OAuth (CLI implemented)
- [x] AWS credentials imported correctly (CLI implemented)

### Checkpoint 3: Workflow Works
- [ ] `devbox create` clones repo and enters Nix shell
- [x] `devbox attach` connects to running shell
- [ ] Detach (Ctrl+P,Q) leaves container running
- [ ] Reattach reconnects to same session
- [ ] `gh` commands work inside container
- [ ] `claude` commands work inside container (both modes)

### Checkpoint 4: Full Loop
- [ ] Create container for real repo with `flake.nix`
- [ ] Run dev server with port mapping
- [ ] Access dev server from host browser
- [ ] Make code changes, verify they persist
- [ ] Stop, start, reattach - state preserved
- [ ] Remove container, verify cleanup

---

## Known Risks / To Validate

- [ ] **Nix in Docker**: Test Determinate installer actually works in container
- [ ] **CLAUDE_CONFIG_DIR**: Verify this env var is correct (may need different approach)
- [ ] **Token refresh**: Confirm Claude handles refresh automatically
- [ ] **ARM64 Nix**: Verify Nix works on Apple Silicon via Docker
- [ ] **Large repos**: Test clone/attach performance with large monorepos
