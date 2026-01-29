# Git Hooks

## Automatic Installation

When you enter the Nix development shell (`nix develop` or via direnv), the git hooks are **automatically installed** from this directory to `.git/hooks/` via symlinks.

No manual setup required!

## Pre-commit Hook

The pre-commit hook automatically runs before every commit to ensure code quality.

### What it does:

1. **Linting** - Runs `shellcheck` on all bash scripts
2. **Formatting** - Checks code formatting with `shfmt`
3. **Testing** - Runs basic tests and critical integration tests

### Running manually:

```bash
# Test the pre-commit hook without committing
.git/hooks/pre-commit
```

### Fixing issues:

If the pre-commit hook fails, it will tell you what's wrong:

**Linting errors:**
```bash
shellcheck bin/devbox tests/*.sh
```

**Formatting errors:**
```bash
# Fix formatting automatically
shfmt -w bin/devbox tests/*.sh docker/*.sh install.sh completions/devbox.bash

# Or use the alias if in nix shell
devbox-format
```

**Test failures:**
- Review the test output
- Fix the failing code
- Run tests again: `./tests/test_cli_basic.sh`

### Bypassing the hook (not recommended):

If you absolutely need to commit without running the hook:
```bash
git commit --no-verify -m "message"
```

**Warning:** Only use `--no-verify` in emergencies. The hook exists to catch issues before they're committed.

### What checks are excluded:

The hook ignores some less critical shellcheck warnings:
- SC2155 - Declare and assign separately (common pattern)
- SC2329 - Function never invoked (test helper functions)
- SC1091/SC1090 - Not following sources (external files)
- SC2034 - Variable appears unused (test setup)
- SC2076/SC2086 - Quoting preferences (intentional patterns)
- SC2207/SC2206 - Array operations (safe in context)
- SC2024 - sudo redirect pattern (intentional)

### Docker requirement:

The hook will skip Docker integration tests if Docker is not running. It will still run:
- Shellcheck (linting)
- shfmt (formatting)
- Basic CLI tests (no Docker needed)
- Install script tests
- Completion standalone tests
