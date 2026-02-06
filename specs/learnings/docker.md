# Docker Patterns

Docker integration patterns for the devbox CLI.

## Container Inspection

`docker port` only works for running containers. Use `docker inspect` instead:

```bash
# Works for BOTH running and stopped containers
ports=$(docker inspect --format '{{range $p, $conf := .HostConfig.PortBindings}}{{range $conf}}{{$p}} -> {{if .HostIp}}{{.HostIp}}{{else}}0.0.0.0{{end}}:{{.HostPort}}{{"\n"}}{{end}}{{end}}' "$container_id")
```

- `.NetworkSettings.Ports` - runtime state (empty when stopped)
- `.HostConfig.PortBindings` - configured ports (always available)

## Container Labels

Labels store container configuration (egress profile, mode, etc.):

```bash
# Set at creation
docker run --label devbox.egress=standard ...

# Query later
docker inspect --format '{{index .Config.Labels "devbox.egress"}}' "$container"
```

**Important**: Labels are immutable after creation. Docker does NOT support `docker container update --label-add`. For runtime-modifiable config, use file-based storage at `~/.devbox/<feature>/<container>/`.

## Image Building

Build on-demand rather than requiring pre-built images:

```bash
ensure_image() {
    if ! docker image inspect "$DEVBOX_IMAGE" &>/dev/null; then
        log_info "Building devbox image..."
        docker build -t "$DEVBOX_IMAGE" "$SCRIPT_DIR/docker"
    fi
}
```

## Docker-in-Docker (DinD)

**Never mount host Docker socket** - allows container escape:
```bash
# DANGEROUS - never do this
docker run -v /var/run/docker.sock:/var/run/docker.sock ...
```

Use DinD with minimal capabilities instead:
```bash
docker run \
    --cap-add=SYS_ADMIN \
    --cap-add=NET_ADMIN \
    --cap-add=MKNOD \
    --security-opt seccomp=unconfined \
    --security-opt apparmor=unconfined \
    --cgroupns=private \
    ...
```

Avoid `--privileged` - grants all capabilities unnecessarily.

## Docker Daemon in Container

Only listen on Unix socket, never TCP:
```bash
# Safe
dockerd --host=unix:///var/run/docker.sock

# DANGEROUS - network-accessible
dockerd --host=tcp://0.0.0.0:2375
```

## Secrets Injection

Never use environment variables for secrets (visible in `docker inspect`):

```bash
# WRONG
docker run -e GITHUB_TOKEN=secret123 ...

# RIGHT - use volumes
docker volume create mycontainer-secrets
# Populate via setup container, then mount
docker run -v mycontainer-secrets:/run/secrets:ro ...
```

Use base64 encoding when passing through shell commands to handle special characters.

## Setup Container Pattern

Configure things requiring root (sudoers, etc.) via temporary setup container:

```bash
# Create config volume
docker volume create mycontainer-config

# Run setup as root
docker run --rm \
    -v mycontainer-config:/config \
    "$IMAGE" \
    sh -c 'echo "devbox ALL=(ALL) NOPASSWD: ALL" > /config/sudoers.d/devbox'

# Mount into main container
docker run -v mycontainer-config:/etc/sudoers.d:ro ...
```
