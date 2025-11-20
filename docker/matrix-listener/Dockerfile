# Rocket Matrix Listener - Connects Matrix to inference server
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    jq \
    python3 \
    python3-pip \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Clone aria-autonomous-infrastructure repo (for V2.0 libraries)
WORKDIR /root
RUN git clone https://github.com/Buckmeister/aria-autonomous-infrastructure.git

# Create config directory
RUN mkdir -p /root/aria-autonomous-infrastructure/config

# Copy Matrix credentials (will be mounted as volume)
VOLUME ["/root/aria-autonomous-infrastructure/config"]

# Working directory
WORKDIR /root/aria-autonomous-infrastructure

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD pgrep -f matrix-conversational-listener || exit 1

# Run listener
CMD ["bash", "-c", "CONFIG_FILE=/root/aria-autonomous-infrastructure/config/matrix-credentials.json ./bin/matrix-conversational-listener.sh"]
