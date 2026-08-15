# ============================================================
# OmniRoute - Dockerfile for Railway (1GB RAM Optimized)
# ============================================================

FROM node:20-slim AS base

# ⚠️ IMPORTANT: Do NOT hardcode PORT here.
# Railway injects the $PORT variable dynamically at runtime.
ENV HOST=0.0.0.0

# ============================================================
# System dependencies
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    sqlite3 \
    ca-certificates \
    python3 \
    python3-pip \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# 🚨 CRITICAL: Memory optimization for Railway 1GB RAM
# ============================================================
# 896MB for Node.js heap (leaves ~128MB for OS + buffers)
ENV NODE_OPTIONS="--max-old-space-size=896"

# Disable Node.js telemetry and unnecessary features
ENV NODE_NO_WARNINGS=1
ENV NODE_ENV=production

# ============================================================
# 🚨 CRITICAL: Storage encryption key (prevents memory leaks)
# ============================================================
ENV STORAGE_ENCRYPTION_KEY="a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"

# ============================================================
# OmniRoute configuration for low-memory environments
# ============================================================
ENV OMNIROUTE_MAX_CONCURRENT=2
ENV OMNIROUTE_REQUEST_TIMEOUT=60
ENV OMNIROUTE_COMPRESSION_MODE=lite
ENV OMNIROUTE_MAX_FALLBACK_ATTEMPTS=1
ENV OMNIROUTE_CIRCUIT_BREAKER_THRESHOLD=3
ENV OMNIROUTE_KEY_COOLDOWN=30
ENV OMNIROUTE_TELEMETRY=0
ENV OMNIROUTE_ANALYTICS=0
ENV OMNIROUTE_LOG_LEVEL=warn
ENV OMNIROUTE_LOG_REQUESTS=0

# Data directory
ENV OMNIROUTE_DATA_DIR=/app/data
ENV OMNIROUTE_DB_PATH=/root/.omniroute/storage.sqlite
ENV OMNIROUTE_CONFIG_PATH=/app/data/config.json

# ============================================================
# Install OmniRoute
# ============================================================
WORKDIR /app

# Install omniroute globally
RUN npm install -g omniroute@latest

# ============================================================
# Create data directories
# ============================================================
RUN mkdir -p /app/data \
    /app/data/sessions \
    /app/data/providers \
    /app/data/compression \
    /app/data/logs \
    /root/.omniroute

# ============================================================
# Copy entrypoint script
# ============================================================
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# ============================================================
# Expose port (Railway will inject $PORT)
# ============================================================
EXPOSE 20128

# Note: Dockerfile HEALTHCHECK was intentionally removed.
# Railway uses its own aggressive platform-level healthcheck
# (which polls /health). Docker's internal healthcheck
# sometimes interferes with Railway's networking layer.

# ============================================================
# Start
# ============================================================
ENTRYPOINT ["/app/entrypoint.sh"]
