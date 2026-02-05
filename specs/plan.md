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
- [x] Check for `flake.nix` or `shell.nix`, fall back to basic bash if missing
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
- [x] Confirmation prompt before removal (skipped with --force)
- [x] Fixed `rm -a` loop to remove all containers (arithmetic with `set -e` bug)
- [x] Complete test suite with 14 comprehensive tests

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
- [x] Colored output (green success, red error, yellow warning) - implemented in log_info/log_success/log_warning/log_error functions
- [x] Progress indicators for long operations - implemented in lib/progress.sh with spinner animations
- [x] Confirm prompt for `rm` without `--force` - prompts user to type 'y' before removal

### Shell Completion
- [x] Create `completions/devbox.bash`
- [x] Complete commands
- [x] Complete container names for attach/stop/start/rm/logs/exec
- [x] Complete flags per command
- [x] Comprehensive test suite for all completion scenarios
- [x] Added to pre-commit hook
- [x] Fix portability: add fallback for _init_completion (works without bash-completion package)

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
- [x] `devbox create` clones repo and enters Nix shell
- [x] `devbox attach` connects to running shell
- [x] Detach (Ctrl+P,Q) leaves container running
- [x] Reattach reconnects to same session
- [x] `gh` commands work inside container
- [x] `claude` commands work inside container (both modes)
- [x] Integration test script (`tests/test_checkpoint3_integration.sh`)

### Checkpoint 4: Full Loop
- [ ] Create container for real repo with `flake.nix`
- [ ] Run dev server with port mapping
- [ ] Access dev server from host browser
- [ ] Make code changes, verify they persist
- [ ] Stop, start, reattach - state preserved
- [ ] Remove container, verify cleanup

---

## Phase 5: Security

### Secrets Management
Replace environment variable approach (GITHUB_TOKEN) with a proper secrets system.

#### `devbox secrets add <name>`
- [x] Store secret in `~/.devbox/secrets/` (uses file permissions, not encryption)
- [x] Use file permissions (600) to restrict access
- [x] Support `--from-env <VAR>` to read from environment variable
- [x] Support `--from-file <path>` to read from file
- [x] Validate secret name (alphanumeric, underscores, hyphens only)
- [x] Overwrite existing secret with `--force` flag
- [x] Comprehensive test suite (23 tests)
- Note: Interactive input (prompting) intentionally not implemented to avoid accidental exposure

#### `devbox secrets remove <name>`
- [x] Remove secret from storage
- [x] Confirmation prompt before removal
- [x] Support `--force` to skip confirmation
- [x] Error if secret doesn't exist

#### `devbox secrets list`
- [x] List all stored secret names (never show values)
- [x] Show creation/modification timestamps
- [ ] Indicate which secrets are in use by containers (future enhancement)

#### Container Integration
- [x] Add `--secret <name>` flag to `devbox create`
- [x] On container start, inject secret into container securely
- [x] Use secret for GitHub auth inside container (via GITHUB_TOKEN env read from /run/secrets)
- [x] Secret passed via file mount to /run/secrets (not command-line)
- [x] Secret not stored in container environment or labels when using --secret
- [x] Support multiple `--secret` flags for different credentials
- [x] Runtime secrets stored in ~/.devbox/runtime-secrets/<container>/ with proper permissions
- [x] Runtime secrets cleaned up when container is removed
- [x] Comprehensive test suite (6 new tests for secure secret injection)

#### Storage Implementation
- [x] Create `~/.devbox/secrets/` directory with 700 permissions
- [x] Store each secret as individual file with 600 permissions
- [x] Add `devbox secrets path` command to show secrets directory location
- [ ] Optional: Add encryption (GPG or age) for additional security (future enhancement)

#### Bash Completion
- [x] Added secrets subcommand completion
- [x] Added secrets add/remove/list/path flag completion
- [x] Added secret name completion for remove command

#### Migration
- [x] Deprecation warning when GITHUB_TOKEN env var is detected
- [x] `devbox secrets import-env` to migrate from env vars to secrets
- [x] Update documentation to recommend secrets over env vars

### Docker-in-Docker Isolation
Replace host Docker socket mounting with an isolated inner daemon for security.

#### Problem
Mounting `-v /var/run/docker.sock:/var/run/docker.sock` allows containers to access the host Docker daemon, which is a security risk. A container could escape by mounting the host filesystem (`-v /:/host`).

#### Solution: Inner Docker Daemon
- [x] Install Docker daemon in Dockerfile (docker-ce + docker-ce-cli already installed)
- [x] Start inner dockerd in entrypoint when `DEVBOX_DOCKER_IN_DOCKER=true`
  - Uses vfs storage driver for simplicity
  - Waits for daemon readiness with 60s timeout
  - Graceful degradation if startup fails
- [x] Remove host socket mount from `devbox create`
  - Removed socket detection for rootless/root/Colima
  - Always use `--privileged` and `DEVBOX_DOCKER_IN_DOCKER=true`
  - Container uses its own isolated daemon instead
- [x] Test docker works inside container (checkpoint3 integration test)
- [x] Verify isolation: Inner containers cannot access host filesystem

#### Benefits
- Docker/docker-compose work inside the container
- Containers created inside are isolated from host
- Host filesystem cannot be mounted from within devbox container

### Security Hardening

#### Docker Opt-in
- [x] Add `--enable-docker` flag to `devbox create`
- [x] Docker-in-Docker disabled by default (reduces attack surface)
- [x] Update help text and documentation

#### Sudo Configuration
- [x] Remove default passwordless sudo from Dockerfile
- [x] Add `--sudo` flag with modes: `nopass`, `password`
- [x] For password mode, prompt user and generate SHA-512 hash
- [x] Configure sudo via setup container (similar to secrets pattern)
- [x] Clean up sudoers volume when container is removed

#### Minimal Capabilities
- [x] Replace `--privileged` with specific capabilities:
  - `SYS_ADMIN` (for mounting)
  - `NET_ADMIN` (for network namespaces)
  - `MKNOD` (for device nodes)
- [x] Add security options: `seccomp=unconfined`, `apparmor=unconfined`
- [x] Add `cgroupns=private` for cgroup isolation

#### No TCP Socket
- [x] Remove `--host=tcp://0.0.0.0:2375` from dockerd startup
- [x] Inner Docker daemon only listens on Unix socket

#### Testing
- [x] Test no Docker/sudo by default
- [x] Test --enable-docker adds correct capabilities
- [x] Test --sudo modes
- [x] Test entrypoint has no TCP socket
- [x] Update bash completion for new flags

### Token-Based Claude Authentication

Replace OAuth flow in `devbox init` with token-based authentication via `claude setup-token`.

#### Problem
The OAuth flow during `devbox init` is unreliable and requires browser interaction inside a container. Users need a simpler, more portable approach.

#### Solution: Token-Based Auth
- [x] Replace `--secret` flag with `--github-secret` and `--claude-code-secret` in `devbox create`
- [x] Users run `claude setup-token` externally to get OAuth token
- [x] Store token as devbox secret (`devbox secrets add claude-oauth-token`)
- [x] Entrypoint reads token from `/run/secrets/claude_code_token`
- [x] Export `CLAUDE_CODE_OAUTH_TOKEN` environment variable inside container
- [x] Token not visible in `docker inspect` (set at runtime in entrypoint)
- [x] Remove Claude OAuth flow from `devbox init` and `init-credentials.sh`
- [x] Bedrock mode unchanged (only needs `--github-secret`)

#### Validation Rules
- Non-Bedrock (OAuth) mode: Both `--github-secret` AND `--claude-code-secret` required
- Bedrock mode: Only `--github-secret` required

#### Testing
- [x] Test `--github-secret` flag validation
- [x] Test `--claude-code-secret` flag validation
- [x] Test OAuth mode requires both secrets
- [x] Test Bedrock mode works without Claude secret
- [x] Test secrets mounted correctly to `/run/secrets/`
- [x] Test tokens not in environment variables (security)

#### Documentation
- [x] Update README.md with new workflow
- [x] Update bash completion
- [x] Update help text

---

## Phase 6: Network Egress Control

Control outbound network access from devbox containers with security profiles and domain/IP filtering.

### Design Decisions
- **Default profile:** `standard` (secure by default with dev-friendly allowlist)
- **DNS proxy:** Per-container sidecar for isolated domain filtering
- **DinD scope:** Outer container only (inner Docker unrestricted)

### Architecture
- Custom Docker networks for per-container isolation
- DNS proxy sidecar (dnsmasq) for domain-level filtering
- iptables rules via DOCKER-USER chain for IP/port filtering

### Security Profiles

#### Profile Configuration
- [x] Create `profiles/` directory structure
- [x] Create `profiles/permissive.conf` - all egress allowed
- [x] Create `profiles/standard.conf` - dev-friendly allowlist
- [x] Create `profiles/strict.conf` - minimal allowlist
- [x] Create `profiles/airgapped.conf` - no network

#### Profile Implementation
- [x] `permissive`: All egress allowed (current behavior) - configuration ready
- [x] `standard`: DNS filtering with default allowlist (pkg managers, git hosts, cloud APIs) - configuration ready
- [x] `strict`: Only explicit allowlist, all else blocked - configuration ready
- [x] `airgapped`: `--network none`, no connectivity - configuration ready

### Default Allowlist (Standard Profile)

#### Allowed Ports
- [x] 53 (DNS), 22 (SSH), 80 (HTTP), 443 (HTTPS), 9418 (Git)

#### Allowed Domains
- [x] Package managers: npmjs.org, pypi.org, crates.io, rubygems.org, cache.nixos.org
- [x] Git hosts: github.com, gitlab.com, bitbucket.org
- [x] Container registries: docker.io, ghcr.io, gcr.io
- [x] Cloud APIs: amazonaws.com, googleapis.com, azure.com, anthropic.com

#### Blocked by Default
- [x] Data exfiltration vectors: pastebin.com, transfer.sh, ngrok.io

### CLI Flags for `devbox create`
- [x] `--egress <profile>` flag (permissive|standard|strict|airgapped)
- [x] `--allow-domain <domain>` flag (repeatable)
- [x] `--allow-ip <ip/cidr>` flag (repeatable)
- [x] `--allow-port <port>` flag (repeatable)
- [x] `--block-domain <domain>` flag (repeatable)
- [x] `--block-ip <ip/cidr>` flag (repeatable)
- [x] Default to `standard` profile when `--egress` not specified

### `devbox network` Subcommand
- [x] `devbox network show <container>` - display current egress rules
- [x] `devbox network allow <container> --domain|--ip|--port` - add allow rule
- [x] `devbox network block <container> --domain|--ip` - add block rule
- [x] `devbox network logs <container>` - view egress logs
- [x] `devbox network logs <container> --blocked-only` - view only blocked attempts
- [x] `devbox network reset <container>` - reset to profile defaults

### Network Helper Library
- [x] Create `lib/network.sh` with helper functions
- [x] `create_container_network()` - create isolated Docker network
- [x] `start_dns_proxy()` - start dnsmasq sidecar container (supports static IP for restarts)
- [x] `restart_dns_proxy()` - restart DNS proxy with new profile, preserving IP for connectivity
- [ ] `setup_iptables_rules()` - apply firewall rules via setup container (TODO: runtime enforcement)
- [x] `cleanup_network_resources()` - remove network, DNS container, iptables rules

### DNS Proxy (dnsmasq)
- [x] DNS proxy using alpine + dnsmasq (inline container, no separate Dockerfile needed)
- [x] Block domains via dnsmasq address=/#domain/# syntax
- [x] Configure container to use DNS proxy as resolver (--dns flag)
- [x] Implement domain allowlist via dnsmasq configuration for strict profile
  - When `DEFAULT_ACTION="drop"`: blocks all domains by default (`address=/#/`), allows only whitelisted domains (`server=/domain/upstream`)
  - When `DEFAULT_ACTION="accept"`: allows all domains, blocks only specific domains (standard mode)
- [ ] Create dedicated `docker/dns-proxy/Dockerfile` for production (TODO: future enhancement)
- [ ] Log blocked DNS queries for audit (TODO: future enhancement)

### iptables Integration
- [ ] Create per-container chain in DOCKER-USER (TODO: future enhancement)
- [ ] Apply port filtering rules (TODO: future enhancement)
- [ ] Apply IP/CIDR filtering rules (TODO: future enhancement)
- [ ] Log blocked connections with identifiable prefix (TODO: future enhancement)
- [ ] Cleanup rules when container removed (TODO: future enhancement)

### Container Labels
- [x] Store egress profile in label: `devbox.egress`
- [x] Store egress profile in label: `devbox.egress`
- [x] Update `devbox list` to show EGRESS column

### Runtime Rule Persistence
- [x] Store runtime-added rules in files at `~/.devbox/egress-rules/<container>/`
  - Note: Docker doesn't support adding labels to running containers, so file-based storage is used
  - Files: `allow-domains.txt`, `block-domains.txt`, `allow-ips.txt`, `block-ips.txt`, `allow-ports.txt`
- [x] Re-apply rules on container restart via `devbox start`
  - `cmd_start()` checks for custom rules and restarts DNS proxy with merged configuration
- [ ] Update DNS proxy allowlist dynamically without restart (TODO: future enhancement)

### Cleanup Integration
- [x] Update `cmd_rm` to remove container network (via cleanup_network_resources)
- [x] Update `cmd_rm` to remove DNS proxy sidecar (via cleanup_network_resources)
- [ ] Update `cmd_rm` to remove iptables rules (TODO: when iptables rules implemented)

### Testing

#### Unit Tests
- [x] Create `tests/test_network_egress.sh`
- [x] Test `--egress` flag parsing
- [x] Test profile configuration loading
- [x] Test `--allow-domain`, `--allow-ip`, `--allow-port` flags
- [x] Test `--block-domain`, `--block-ip` flags
- [x] Test default profile is `standard`

#### Integration Tests
- [x] Test airgapped mode blocks all network (airgapped enforcement implemented with --network none)
- [x] Test standard mode creates DNS proxy container
- [x] Test standard mode blocks pastebin.com (via DNS proxy NXDOMAIN)
- [x] Test DNS proxy and network cleanup on container removal
- [x] Test strict profile DNS allowlist blocks non-whitelisted domains
- [x] Test standard mode allows package manager domains (registry.npmjs.org resolves)
- [x] Test `--allow-domain` adds custom domain access
- [x] Test `devbox network reset` help and validation
- [x] Test `devbox network reset --dry-run` shows what would be done
- [x] Test `devbox network reset` recreates DNS proxy with profile defaults
- [x] Test `restart_dns_proxy` preserves IP address for connectivity
- [x] Test `get_custom_egress_rules_from_labels` reads rules from files
- [x] Test `devbox start` re-applies custom egress rules after stop/start cycle
- [ ] Test DNS proxy logs queries (TODO: future enhancement)
- [ ] Test iptables rules applied correctly (TODO: when iptables rules implemented)

### Bash Completion
- [x] Add `--egress` flag completion with profile values
- [x] Add `--allow-domain`, `--allow-ip`, `--allow-port` completion
- [x] Add `--block-domain`, `--block-ip` completion
- [x] Add `devbox network` subcommand completion
- [x] Add container name completion for network commands

### Documentation
- [x] Update README.md with egress control section
- [x] Document security profiles and use cases
- [x] Document default allowlist domains
- [x] Document runtime rule management
- [ ] Add troubleshooting for blocked connections (TODO: when enforcement implemented)

---

## Phase 7: Website Deployment

Deploy the Vite + React marketing website to GitHub Pages.

### Website Build (CI)
- [x] Add `web-build` job to `.github/workflows/ci.yml`
  - Install pnpm and Node.js 20
  - Run TypeScript type checking
  - Build project with Vite
  - Verify output files exist

### GitHub Pages Deployment
- [x] Create `.github/workflows/deploy-pages.yml`
  - Trigger on push to main (with path filter for `web/`)
  - Support manual trigger via `workflow_dispatch`
  - Use official GitHub Pages actions (configure-pages, upload-pages-artifact, deploy-pages)
  - Set `VITE_BASE_PATH=/devbox/` for correct asset paths

### Configuration Updates
- [x] Update `web/vite.config.ts` with dynamic base path support
- [x] Fix favicon reference in `web/index.html`

### Post-Deployment Setup
- [ ] Enable GitHub Pages in repository settings (Source: "GitHub Actions")
- [ ] Verify deployment at https://testaco.github.io/devbox/

---

## Phase 8: Audit & Observability

Comprehensive logging for AI agents and automated workloads that interact with external services.

### Audit Log Infrastructure

#### CLI Flags
- [ ] `--audit-log <path>` flag on `devbox create` to enable audit logging
- [ ] `--audit-level <level>` flag (minimal|standard|verbose)
- [ ] Default: no audit logging (opt-in for privacy)

#### Log Storage
- [ ] Create `lib/audit.sh` with logging helpers
- [ ] Store logs at specified path or default `~/.devbox/audit/<container>/`
- [ ] Structured JSON format for machine parsing
- [ ] Log rotation (configurable max size/age)

### Log Categories

#### Network Activity (NET)
- [ ] `NET_OUT` - outbound HTTP/HTTPS requests (domain, method, path, size)
- [ ] `NET_BLOCKED` - blocked connection attempts (domain/IP, reason)
- [ ] `NET_DNS` - DNS queries (already partial via dnsmasq logs)
- [ ] Implementation: HTTP proxy sidecar (mitmproxy or similar)

#### File Access (FILE)
- [ ] `FILE_READ` - files read by processes
- [ ] `FILE_WRITE` - files created/modified
- [ ] `FILE_DELETE` - files removed
- [ ] Filter: workspace files only (ignore /tmp, system files)
- [ ] Implementation: inotifywait or eBPF

#### Process Execution (EXEC)
- [ ] `EXEC` - commands executed (command, args, exit code)
- [ ] `EXEC_BLOCKED` - blocked commands (if command filtering enabled)
- [ ] Implementation: auditd or eBPF

#### External API Calls (API)
- [ ] `API_CALL` - calls to known APIs (anthropic, openai, etc.)
- [ ] Track: endpoint, token count, estimated cost
- [ ] Aggregate: periodic summary of API usage/spend
- [ ] Implementation: HTTP proxy with API detection

#### Message Activity (MSG) - for messaging integrations
- [ ] `MSG_OUT` - outbound messages (destination, preview/hash)
- [ ] `MSG_IN` - inbound messages (source, preview/hash)
- [ ] Content: truncated preview or hash-only mode for privacy
- [ ] Implementation: HTTP proxy parsing known messaging APIs

### Audit CLI Commands

#### `devbox audit <container>`
- [ ] View audit log with filtering
- [ ] `--category <cat>` - filter by category (NET, FILE, EXEC, API, MSG)
- [ ] `--since <time>` - filter by time (1h, 24h, 7d)
- [ ] `--blocked-only` - show only blocked/denied actions
- [ ] `--json` - output raw JSON for scripting

#### `devbox audit <container> --tail -f`
- [ ] Follow audit log in real-time
- [ ] Useful for monitoring agent activity live

#### `devbox audit <container> --summary`
- [ ] Show aggregated statistics
- [ ] API calls and estimated costs
- [ ] Top domains contacted
- [ ] Files modified
- [ ] Commands executed

### HTTP Proxy Sidecar

#### Implementation
- [ ] Create `docker/audit-proxy/` with mitmproxy or similar
- [ ] Transparent proxy mode (container traffic routed through)
- [ ] TLS interception with generated CA (optional, for HTTPS inspection)
- [ ] Log all requests to audit log
- [ ] Minimal performance overhead

#### Privacy Modes
- [ ] `--audit-level minimal` - domains/IPs only, no content
- [ ] `--audit-level standard` - headers + truncated body preview
- [ ] `--audit-level verbose` - full request/response bodies

### Resource Monitoring

#### Container Limits
- [ ] `--memory <limit>` flag (e.g., `4g`)
- [ ] `--cpus <limit>` flag (e.g., `2`)
- [ ] `--pids-limit <n>` flag (prevent fork bombs)

#### Resource Logging
- [ ] `RESOURCE` - periodic snapshots (cpu%, mem%, net I/O)
- [ ] `RESOURCE_ALERT` - threshold exceeded events
- [ ] Configurable thresholds and intervals

### Rate Limiting (Future)

#### Per-Domain Limits
- [ ] `--rate-limit <domain>:<n>/<period>` flag
- [ ] Example: `--rate-limit "api.whatsapp.com:10/hour"`
- [ ] Enforced at HTTP proxy level

#### Approval Queue (Future)
- [ ] `--approval-required <domain>:<method>` flag
- [ ] Intercept matching requests for human approval
- [ ] Notification via webhook or local socket
- [ ] Timeout with configurable default (approve/deny)

### Testing

#### Unit Tests
- [ ] Create `tests/test_audit.sh`
- [ ] Test `--audit-log` flag parsing
- [ ] Test audit log file creation and permissions
- [ ] Test log rotation

#### Integration Tests
- [ ] Test NET_OUT logging captures HTTP requests
- [ ] Test FILE_WRITE logging captures file changes
- [ ] Test EXEC logging captures command execution
- [ ] Test `devbox audit` command output
- [ ] Test `--audit-level` modes

### Bash Completion
- [ ] Add `--audit-log` flag completion
- [ ] Add `--audit-level` with value completion
- [ ] Add `devbox audit` subcommand completion
- [ ] Add `--category` values completion

### Documentation
- [ ] Document audit logging setup and use cases
- [ ] Document log format specification
- [ ] Document privacy considerations
- [ ] Add examples for AI agent monitoring

---

## Known Risks / To Validate

- [ ] **Nix in Docker**: Test Determinate installer actually works in container
- [x] ~~**CLAUDE_CONFIG_DIR**: Verify this env var is correct~~ - Now using CLAUDE_CODE_OAUTH_TOKEN
- [ ] **Token refresh**: Users must refresh tokens manually via `claude setup-token`
- [ ] **ARM64 Nix**: Verify Nix works on Apple Silicon via Docker
- [ ] **Large repos**: Test clone/attach performance with large monorepos
