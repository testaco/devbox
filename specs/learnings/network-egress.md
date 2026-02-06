# Network Egress Control

Network isolation and egress filtering patterns.

## Security Profiles

Default to restricted, not permissive:

| Profile | Description |
|---------|-------------|
| `standard` | Common dev tools (package managers, git hosts, cloud APIs) |
| `strict` | Allowlist only - explicit domains required |
| `airgapped` | No network access (`--network none`) |
| `permissive` | Unrestricted (escape hatch) |

Store profiles in `profiles/*.conf` for easy customization.

## Implementation Layers

Effective egress control uses multiple mechanisms:

1. **Docker networks** - Container isolation
2. **DNS proxy sidecar** - Domain-level filtering
3. **iptables rules** - IP/port filtering

## Airgapped Mode

Simplest - uses Docker's built-in isolation:

```bash
docker run --network none ...
```

## DNS Proxy Sidecar

Use dnsmasq in a sidecar for domain filtering:

```bash
# Create network
docker network create devbox-mycontainer-net

# Start DNS proxy
docker run -d --name devbox-mycontainer-dns \
    --network devbox-mycontainer-net \
    alpine sh -c 'apk add dnsmasq && dnsmasq --no-daemon ...'

# Get proxy IP (poll until available)
dns_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' devbox-mycontainer-dns)

# Start main container with custom DNS
docker run --network devbox-mycontainer-net --dns "$dns_ip" ...
```

### Blocklist Mode

Allow all, block specific domains:

```
# dnsmasq.conf
server=8.8.8.8
server=1.1.1.1
address=/blocked-domain.com/#  # Returns NXDOMAIN
```

### Allowlist Mode

Block all, allow specific domains:

```
# dnsmasq.conf
address=/#/  # Block everything by default
server=/allowed-domain.com/8.8.8.8  # Forward only these
server=/another-allowed.com/8.8.8.8
```

## Static IP for DNS Proxy

Docker's `--dns` is set at container creation and can't be changed. For dynamic updates (like `devbox network reset`), use static IP:

```bash
# Assign specific IP to DNS proxy
docker run --network mynet --ip 172.18.0.2 ...

# When restarting proxy with new config, use same IP
old_ip=$(docker inspect -f '...' old-dns-container)
docker rm -f old-dns-container
docker run --network mynet --ip "$old_ip" ...  # Main container keeps working
```

## Runtime Configuration

Labels are immutable after creation. Use file-based storage for rules added later:

```
~/.devbox/egress-rules/<container>/
  allowed-domains    # One domain per line
  blocked-domains
```

Re-apply from files during `cmd_start()`.

## Kernel Module Limitations

`--opt "com.docker.network.bridge.enable_icc=false"` requires `br_netfilter` kernel module. Implement fallback:

```bash
if ! docker network create --opt "com.docker.network.bridge.enable_icc=false" ...; then
    # Fallback to standard bridge
    docker network create ...
fi
```

## Cleanup

Remove both DNS container and network when removing main container:

```bash
docker rm -f "devbox-$name-dns" 2>/dev/null || true
docker network rm "devbox-$name-net" 2>/dev/null || true
```
