FROM debian:bookworm-slim

# Install minimal dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    xz-utils \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user with UID 1000
RUN groupadd -g 1000 devbox 2>/dev/null || true && \
    useradd -u 1000 -g 1000 -m -s /bin/bash devbox && \
    echo "devbox ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install Nix as devbox user (single-user mode)
USER devbox
WORKDIR /home/devbox

# Create Nix config directory and enable flakes
RUN mkdir -p /home/devbox/.config/nix && \
    echo "experimental-features = nix-command flakes" > /home/devbox/.config/nix/nix.conf

# Install Nix (single-user, no daemon)
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# Ensure Nix is in PATH
ENV PATH="/home/devbox/.nix-profile/bin:$PATH"

# Switch to root for Docker installation
USER root

# Install Docker daemon for DinD capability
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-transport-https \
        gnupg \
        lsb-release \
        iptables \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-ce \
    && rm -rf /var/lib/apt/lists/* \
    && usermod -aG docker devbox

# Copy scripts
COPY entrypoint.sh /entrypoint.sh
COPY init-credentials.sh /init-credentials.sh
RUN chmod +x /entrypoint.sh /init-credentials.sh

# Switch back to devbox user
USER devbox
WORKDIR /home/devbox

# Entrypoint handles bootstrap sequence
ENTRYPOINT ["/entrypoint.sh"]