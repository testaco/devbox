# Devbox Project Template

This template provides a starter `flake.nix` for projects using the Devbox platform.

## What You Get

This template inherits all tools from the Devbox base platform:

- **Git/GitHub**: `git`, `gh`
- **AI**: `claude` (Claude Code)
- **AWS**: `aws` (AWS CLI v2)
- **Utilities**: `jq`, `yq`, `curl`, `wget`, `tree`, `htop`
- **Editors**: `vim`, `nano`
- **Shell Dev**: `shellcheck`, `shfmt`, `bats`

## Getting Started

1. **Initialize in your project**:
   ```bash
   nix flake init -t github:system1/devbox?dir=base-flake
   ```

2. **Add your project dependencies**:
   Edit `flake.nix` and uncomment/add packages in the `buildInputs` section:
   ```nix
   buildInputs = with pkgs; [
     nodejs_20      # For Node.js projects
     python311      # For Python projects
     terraform      # For infrastructure
     # ... add more as needed
   ];
   ```

3. **Add project-specific setup**:
   Edit the `shellHook` section to add environment variables, startup commands, etc.

4. **Enter the development environment**:
   ```bash
   nix develop
   ```

## Example Configurations

### Node.js Project
```nix
buildInputs = with pkgs; [
  nodejs_20
  nodePackages.npm
  nodePackages.typescript
];

shellHook = ''
  echo "Installing npm dependencies..."
  npm install
  echo "Run 'npm start' to start the dev server"
'';
```

### Python Project
```nix
buildInputs = with pkgs; [
  python311
  python311Packages.pip
  python311Packages.virtualenv
];

shellHook = ''
  if [ ! -d .venv ]; then
    python -m venv .venv
  fi
  source .venv/bin/activate
'';
```

### Go Project
```nix
buildInputs = with pkgs; [
  go
  gotools
  gopls
];
```

## Updating the Base Platform

To get updates from the devbox base platform:

```bash
nix flake update devbox
```

This will update all the base tools (git, gh, claude, aws, etc.) to the latest versions.
