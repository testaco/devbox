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
- [ ] Define volume structure: `gh/`, `claude/`, `aws/`
- [ ] Create init container script that mounts volume read-write
- [ ] Verify `GH_CONFIG_DIR` env var works for GitHub CLI
- [ ] Verify `CLAUDE_CONFIG_DIR` env var works for Claude Code (or find correct var)
- [ ] Verify `AWS_CONFIG_FILE` and `AWS_SHARED_CREDENTIALS_FILE` work
- [ ] Test read-only mount in work containers

---

## Phase 2: CLI Core

### Script Setup
- [ ] Create `bin/devbox` bash script
- [ ] Add shebang and strict mode (`set -euo pipefail`)
- [ ] Define constants (image name, volume name, container prefix)
- [ ] Add usage/help function
- [ ] Add command dispatcher (case statement)

### `devbox init`
- [ ] Check if credentials volume exists, create if not
- [ ] Parse `--bedrock` flag
- [ ] Parse `--import-aws` flag
- [ ] Run ephemeral init container with volume mounted rw
- [ ] Run `gh auth login --web` inside container
- [ ] If not `--bedrock`: run `claude` to trigger OAuth
- [ ] If `--import-aws`: copy host `~/.aws/*` into volume
- [ ] Print success message with mode (oauth/bedrock)

### `devbox create <name> <repo>`
- [ ] Parse `--port` flag (repeatable)
- [ ] Parse `--bedrock` flag
- [ ] Parse `--aws-profile` flag
- [ ] Validate name doesn't already exist
- [ ] Build docker run command with:
  - [ ] Container name with prefix (`devbox-<name>`)
  - [ ] Credential volume mount (read-only)
  - [ ] Port mappings
  - [ ] Environment variables (repo URL, AWS profile, bedrock flag)
  - [ ] Detached mode with TTY (`-dit`)
- [ ] Store metadata (repo, mode, ports) as container labels
- [ ] Print success message

### `devbox list`
- [ ] Query Docker for containers with devbox prefix
- [ ] Extract labels (repo, mode, ports)
- [ ] Format table output (NAME, ID, STATUS, REPO, PORTS, MODE)

### `devbox attach <name-or-id>`
- [ ] Resolve name to container ID
- [ ] Run `docker attach` with proper TTY settings
- [ ] Handle Ctrl+P,Q detach sequence

### `devbox stop <name-or-id>`
- [ ] Resolve name to container ID
- [ ] Run `docker stop`

### `devbox start <name-or-id>`
- [ ] Resolve name to container ID
- [ ] Run `docker start`

### `devbox rm <name-or-id>`
- [ ] Parse `--force` flag
- [ ] Resolve name to container ID
- [ ] Check if running (error unless --force)
- [ ] Run `docker rm` (with `-f` if forced)

---

## Phase 3: Polish

### Additional Commands
- [ ] `devbox logs <name-or-id>` with `-f` follow flag
- [ ] `devbox exec <name-or-id> <command...>`
- [ ] `devbox ports <name-or-id>`

### Error Handling
- [ ] Check Docker daemon is running
- [ ] Check credentials volume exists before create
- [ ] Friendly error if container name not found
- [ ] Friendly error if repo clone fails
- [ ] Friendly error if no Nix config in repo

### UX Improvements
- [ ] Colored output (green success, red error, yellow warning)
- [ ] Progress indicators for long operations
- [ ] Confirm prompt for `rm` without `--force`

### Shell Completion
- [ ] Create `completions/devbox.bash`
- [ ] Complete commands
- [ ] Complete container names for attach/stop/start/rm/logs/exec
- [ ] Complete flags per command

---

## Phase 4: Distribution

### Installation
- [ ] Create `install.sh` script
- [ ] Copy `bin/devbox` to `/usr/local/bin` or `~/.local/bin`
- [ ] Install bash completion
- [ ] Build and tag Docker image
- [ ] Push image to registry (optional: GitHub Container Registry)

### Documentation
- [ ] Write README.md with quick start
- [ ] Document all commands and flags
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
- [ ] `devbox init` completes GitHub OAuth
- [ ] `devbox init` completes Claude OAuth (non-bedrock)
- [ ] `devbox init --bedrock` skips Claude OAuth
- [ ] AWS credentials imported correctly
- [ ] Credentials persist in volume across container restarts

### Checkpoint 3: Workflow Works
- [ ] `devbox create` clones repo and enters Nix shell
- [ ] `devbox attach` connects to running shell
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
