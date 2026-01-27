FROM debian:bookworm-slim

# Install minimal dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    xz-utils \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user with UID 1000 (matches typical rootless Docker host user)
# This ensures proper permissions when mounting rootless Docker socket
RUN groupadd -g 1000 devbox 2>/dev/null || true && \
    useradd -u 1000 -g 1000 -m -s /bin/bash devbox && \
    echo "devbox ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install Nix using official installer for proper single-user setup
USER devbox
WORKDIR /home/devbox

# Create Nix config directory and configure experimental features
RUN mkdir -p /home/devbox/.config/nix && \
    echo "experimental-features = nix-command flakes" > /home/devbox/.config/nix/nix.conf

# Install Nix using official installer with single-user mode
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# Ensure proper PATH setup for Nix
ENV PATH="/home/devbox/.nix-profile/bin:$PATH"

# Switch back to root for remaining setup
USER root

# Install Docker CLI and Engine (for Docker-on-host access and Docker-in-Docker)
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

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 (architecture-aware)
RUN apt-get update && apt-get install -y unzip \
    && ARCH=$(uname -m) \
    && if [ "$ARCH" = "x86_64" ]; then \
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; \
    else \
        echo "Unsupported architecture: $ARCH" && exit 1; \
    fi \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws \
    && apt-get remove -y unzip && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for Claude Code)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code
# Note: Anthropic recommends native installer, but npm works reliably in containers
RUN npm install -g @anthropic-ai/claude-code

# Copy scripts (as root for proper permissions)
COPY entrypoint.sh /entrypoint.sh
COPY init-credentials.sh /init-credentials.sh
RUN chmod +x /entrypoint.sh /init-credentials.sh

# Switch back to devbox user for final setup
USER devbox
WORKDIR /home/devbox

# Entrypoint handles repo clone and nix shell
ENTRYPOINT ["/entrypoint.sh"]