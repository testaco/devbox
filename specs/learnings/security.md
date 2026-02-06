# Security Patterns

Security best practices for container-based development environments.

## Secrets Management

### Never Prompt Interactively

Interactive prompts risk accidental exposure (shell history, screen sharing):

```bash
# WRONG
read -p "Enter token: " token

# RIGHT - from environment or file
--from-env GITHUB_TOKEN
--from-file ~/.secrets/token
```

### Never Use Environment Variables

Visible in `docker inspect`:

```bash
# WRONG
docker run -e GITHUB_TOKEN=secret123 ...

# RIGHT - use secret volumes
docker run -v container-secrets:/run/secrets:ro ...
```

### Secret Volume Pattern

```bash
# Create volume
docker volume create mycontainer-secrets

# Populate via setup container (runs as root for correct ownership)
echo "$secret_value" | base64 -d | docker run --rm -i \
    -v mycontainer-secrets:/secrets \
    alpine sh -c 'cat > /secrets/token && chmod 600 /secrets/token'

# Mount read-only
docker run -v mycontainer-secrets:/run/secrets:ro ...
```

Use base64 encoding to handle special characters safely.

## Password Hashing

Hash immediately, clear plaintext:

```bash
# Collect password
read -s -p "Password: " password

# Hash with SHA-512
hash=$(openssl passwd -6 "$password")
unset password  # Clear plaintext

# Apply in container
echo "devbox:$hash" | chpasswd -e
```

Never log or display passwords or hashes.

## Privilege Management

### Disabled by Default

Docker and sudo should be opt-in:

```bash
# Require explicit flags
devbox create mybox --enable-docker --sudo nopass
```

### Sudo Configuration

Configure at runtime via setup container, not in Dockerfile:

```bash
# --sudo nopass
echo "devbox ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/devbox

# --sudo password (with hash)
echo "devbox ALL=(ALL) ALL" > /etc/sudoers.d/devbox
```

## Docker-in-Docker Security

Never mount host socket:
```bash
# ALLOWS CONTAINER ESCAPE
docker run -v /var/run/docker.sock:/var/run/docker.sock ...

# Attacker can: docker run -v /:/host ubuntu cat /host/etc/passwd
```

Use DinD with minimal capabilities instead.

## Token-Based Auth

Prefer tokens over interactive OAuth in containers:

1. User runs auth on host: `claude setup-token`
2. Store token as secret: `devbox secrets set claude-token`
3. Inject at runtime in entrypoint (not docker env vars)

```bash
# In entrypoint.sh
if [[ -f /run/secrets/claude-token ]]; then
    export CLAUDE_TOKEN=$(cat /run/secrets/claude-token)
fi
```

## File Permissions

```bash
# Secret files
chmod 600 /path/to/secret

# Secret directories
chmod 700 /path/to/secrets/
```

## Explicit Flag Names

For commands requiring multiple credentials:

```bash
# GOOD - clear validation rules
devbox create --github-secret ghtoken --claude-secret ctoken

# BAD - ambiguous
devbox create --secret ghtoken --secret ctoken
```
