# UX and Installation Patterns

User experience and installation best practices.

## Installation Script

Single command to install everything:

```bash
# System-wide
sudo ./install.sh

# User install (no sudo)
./install.sh --prefix ~/.local

# Preview
./install.sh --dry-run

# Uninstall
./install.sh --uninstall
```

### Key Features

```bash
#!/bin/bash
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
DRY_RUN=false
UNINSTALL=false
SKIP_IMAGE=false

run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "Would run: $*"
    else
        eval "$*"
    fi
}

install_binary() {
    run_cmd "mkdir -p '$PREFIX/bin'"
    run_cmd "cp bin/devbox '$PREFIX/bin/devbox'"
    run_cmd "chmod +x '$PREFIX/bin/devbox'"
}
```

- `--prefix` for custom directories
- `--dry-run` to preview
- `--uninstall` for clean removal
- `--skip-image` / `--skip-completion` for partial installs
- Warn if install dir not in PATH

## Destructive Operations

Require confirmation for irreversible actions:

```bash
cmd_rm() {
    if [[ "$force" != true ]]; then
        echo "This will remove container '$name' and all its data."
        read -p "Continue? [y/N] " confirm
        [[ "$confirm" != [yY]* ]] && return 1
    fi
    # proceed with removal
}
```

- Show what will be affected
- `--force` flag for automation/scripting
- Test both confirmation paths

## Progress Indicators

Spinners for long operations:

```bash
with_spinner "Building image" docker build ...
```

Key points:
- Include guard to prevent double-sourcing: `[[ -n "${_DEVBOX_PROGRESS_LOADED:-}" ]] && return`
- Support non-interactive mode: `DEVBOX_NO_SPINNER=1`
- Detect CI environments
- Cleanup with traps to restore cursor

## Error Messages in Entrypoints

Provide actionable error messages:

```bash
if ! gh repo clone "$REPO_URL" "$REPO_DIR" 2>&1; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✗ ERROR: Failed to clone repository"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Repository: $REPO_URL"
    echo ""
    echo "Possible causes:"
    echo "  • Repository does not exist"
    echo "  • No access to repository"
    echo "  • Network issues"
    echo ""
    echo "To fix:"
    echo "  1. Verify repository URL"
    echo "  2. Check GitHub authentication"
    exit 1
fi
```

Include:
- Visual separators
- Specific error context
- Possible causes
- Remediation steps
- Links to docs if relevant

## Graceful Degradation

Don't fail when optional config is missing:

```bash
# If no flake.nix, just use basic shell
if [[ -f flake.nix ]]; then
    nix develop
else
    exec bash
fi
```

Users can start immediately and add config later.

## Migration Commands

When deprecating features:

1. Show deprecation warning at point of use
2. Provide helper command to migrate: `devbox import-env GITHUB_TOKEN`
3. Explain security context for why new approach is better

## GitHub Pages Deployment

For Vite + React apps:

1. Set `base` in vite.config.ts via `VITE_BASE_PATH` env var
2. Use `actions/upload-pages-artifact` + `actions/deploy-pages`
3. Path filters to only deploy when `web/` changes
4. Enable GitHub Pages with "GitHub Actions" source in repo settings
