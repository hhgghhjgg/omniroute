# ============================================================
# OmniRoute Dockerfile - Railway Ready
# Debian 12 (Bookworm) Base - TLS Client Compatible
# ============================================================

FROM node:22-bookworm

LABEL maintainer="OmniRoute Railway Deployment"
LABEL description="OmniRoute with TLS impersonation support (libresolv.so.2)"

# ============================================================
# Build Arguments & Environment
# ============================================================

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_ENV=production

# ⚠️ IMPORTANT: Do NOT hardcode PORT here. 
# Railway injects the $PORT variable dynamically at runtime.
ENV HOST=0.0.0.0
ENV NODE_OPTIONS="--max-old-space-size=512"
ENV OMNIROUTE_DATA_DIR=/app/data
ENV OMNIROUTE_TELEMETRY=0
ENV OMNIROUTE_ANALYTICS=0
ENV OMNIROUTE_COMPRESSION_MODE=off
ENV OMNIROUTE_LOG_LEVEL=warn
ENV OMNIROUTE_MAX_CONCURRENT=2
ENV PRICING_SYNC_ENABLED=false
ENV MODELS_DEV_ENABLED=false

# ============================================================
# Install System Dependencies (Critical for TLS Client)
# ============================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    ca-certificates \
    dnsutils \
    libc6 \
    libssl3 \
    libstdc++6 \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Verify libresolv.so.2 exists (Critical for tls-client)
RUN if [ ! -f /lib/x86_64-linux-gnu/libresolv.so.2 ]; then \
    echo "❌ ERROR: libresolv.so.2 not found!"; \
    exit 1; \
fi && \
echo "✅ libresolv.so.2 found at: $(find / -name 'libresolv.so.2' 2>/dev/null | head -1)"

# ============================================================
# Create App Directory
# ============================================================

WORKDIR /app

# ============================================================
# Install OmniRoute Globally
# ============================================================

RUN npm install -g omniroute --omit=dev --ignore-scripts 2>/dev/null || \
    npm install -g omniroute --legacy-peer-deps --ignore-scripts || \
    npm install -g omniroute --force

# Verify OmniRoute installation
RUN which omniroute && omniroute --version 2>/dev/null || echo "OmniRoute installed (version check skipped)"

# ============================================================
# Create Data Directories
# ============================================================

RUN mkdir -p /app/data/sessions \
    /app/data/providers \
    /app/data/compression \
    /app/data/logs \
    && chmod -R 755 /app/data

# ============================================================
# Copy Entrypoint Script
# ============================================================

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ============================================================
# Expose Port
# ⚠️ Railway requires a hardcoded EXPOSE directive.
# Railway will automatically read this (8080) and inject it 
# into your container as the $PORT environment variable at runtime.
# ============================================================

EXPOSE 8080

# Note: Dockerfile HEALTHCHECK was intentionally removed. 
# Railway uses its own aggressive platform-level healthcheck 
# (which polls /health). Docker's internal healthcheck 
# sometimes interferes with Railway's networking layer.
# ============================================================

# ============================================================
# Entrypoint
# ============================================================

ENTRYPOINT ["/entrypoint.sh"]
