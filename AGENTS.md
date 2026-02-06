# Agent Development Rules

Quick reference for this project. For detailed examples and rationale, see the linked files.

## Table of Contents

| Topic | Quick Rules | Details |
|-------|-------------|---------|
| CLI Commands | [Rules](#cli-commands) | [cli-patterns.md](specs/learnings/cli-patterns.md) |
| Testing | [Rules](#testing) | [testing.md](specs/learnings/testing.md) |
| Docker | [Rules](#docker) | [docker.md](specs/learnings/docker.md) |
| Bash | [Rules](#bash) | [bash-scripting.md](specs/learnings/bash-scripting.md) |
| Security | [Rules](#security) | [security.md](specs/learnings/security.md) |
| Network Egress | [Rules](#network-egress) | [network-egress.md](specs/learnings/network-egress.md) |
| UX | [Rules](#ux) | [ux-installation.md](specs/learnings/ux-installation.md) |

---

## CLI Commands

- Consistent structure: flag parsing loop → help check → validation → resolve container → execute
- Handle `-h`/`--help` before any validation; errors go to stderr via `log_error()`
- Variable-length args: capture with `exec_command+=("$@")` then `break`
- Skip Docker checks for non-Docker commands (dispatch early in `main()` before `check_docker()`)
- Always add `--dry-run` flag for testing destructive operations

## Testing

- Write tests first; use `--dry-run` for testing destructive operations
- Exit code capture: `set +e; result=$(cmd); code=$?; set -e` (don't use `|| true`)
- Use high ports (>15000) to avoid conflicts; cleanup at start AND end of test suites
- Run `tests/test_checkpoint3_integration.sh` after major CLI/Docker/entrypoint changes
- Bash arithmetic: `((count++)) || true` with `set -e` (increment returns old value)

## Docker

- Use `docker inspect .HostConfig.PortBindings` for ports (works when container is stopped)
- Never mount host Docker socket; use DinD with minimal capabilities (`--cap-add=SYS_ADMIN,NET_ADMIN,MKNOD`)
- Secrets via volumes at `/run/secrets/`, never env vars (visible in `docker inspect`)
- Labels are immutable after creation; use `~/.devbox/<feature>/<container>/` for runtime config
- Setup container pattern: run temp container as root to configure sudoers, then mount into main container

## Bash

- `((count++)) || true` with `set -e` - increment returns old value, exits when count=0
- Indirect variable access: `value="${!varname}"` to read variable by name
- Completion scripts need `_init_completion` fallback for portability (test with `bash --norc --noprofile`)
- Quote args containing spaces when building commands; use `eval` carefully

## Security

- Never prompt for secrets interactively; use `--from-env` or `--from-file` patterns
- Hash passwords immediately with `openssl passwd -6`; clear plaintext from memory
- Sudo/Docker disabled by default; require explicit `--sudo`/`--enable-docker` flags
- Prefer token-based auth over OAuth flows in containers; inject via entrypoint, not docker env
- Use explicit flag names (`--github-secret`, `--claude-secret`) rather than generic `--secret`

## Network Egress

- Default to restricted egress; profiles: `standard`, `strict`, `airgapped`, `permissive`
- DNS proxy sidecar with dnsmasq for domain filtering (allowlist or blocklist mode)
- Static IP assignment (`--ip`) for DNS proxy to survive restarts without breaking main container
- File-based storage at `~/.devbox/egress-rules/<container>/` for runtime-modifiable rules
- Kernel module fallback: try `enable_icc=false`, fall back to standard bridge if unavailable

## UX

- Destructive operations require confirmation prompt; `--force` flag to skip for automation
- Progress spinners for long operations; `DEVBOX_NO_SPINNER=1` or CI detection for non-interactive
- Installation scripts need `--prefix`, `--dry-run`, `--uninstall`, `--skip-image` options
- Entrypoint errors: visual separators, specific context, possible causes, remediation steps
- Graceful degradation: sensible defaults when optional config missing (e.g., no flake.nix → basic shell)
- Migration commands for breaking changes: deprecation warnings + helper commands + security context

---

*Detailed patterns and examples: [specs/learnings/](specs/learnings/README.md)*
