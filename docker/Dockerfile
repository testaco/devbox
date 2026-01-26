FROM debian:bookworm-slim

# Install minimal dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    xz-utils \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user first (Nix needs to be installed as the target user for single-user mode)
RUN useradd -m -s /bin/bash devbox && \
    echo "devbox ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install Nix in single-user mode as devbox user
USER devbox
WORKDIR /home/devbox
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install linux \
    --init none --no-confirm --no-start-daemon \
    --extra-conf "experimental-features = nix-command flakes"

# Switch back to root for remaining setup
USER root

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

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