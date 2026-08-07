FROM node:22-slim

ENV NPM_CONFIG_LOGLEVEL=warn
ENV NODE_ENV=production

WORKDIR /app

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install OmniRoute
RUN npm install -g omniroute --omit=dev 2>/dev/null || \
    npm install -g omniroute --legacy-peer-deps

# Data directory
RUN mkdir -p /app/data && chmod -R 755 /app/data

# ===== RENDER-REQUIRED ENVIRONMENT VARIABLES =====
ENV PORT=10000
ENV HOST=0.0.0.0

# ===== OMNIROUTE ENVIRONMENT VARIABLES =====
ENV OMNIROUTE_DATA_DIR=/app/data
ENV OMNIROUTE_DB_PATH=/app/data/omniroute.db
ENV OMNIROUTE_CONFIG_PATH=/app/data/config.json

# Memory limit
ENV NODE_OPTIONS="--max-old-space-size=384"

# Disable telemetry
ENV OMNIROUTE_TELEMETRY=0
ENV OMNIROUTE_ANALYTICS=0
ENV OMNIROUTE_NO_TELEMETRY=1

# Enable free provider fallback
ENV OMNIROUTE_AUTO_FREE_FALLBACK_TO_FULL_POOL=true

# Compression
ENV OMNIROUTE_COMPRESSION_MODE=stacked
ENV OMNIROUTE_COMPRESSION_LLMLINGUA=0

# Routing
ENV OMNIROUTE_DEFAULT_STRATEGY=auto
ENV OMNIROUTE_FALLBACK_ENABLED=1

# Logging
ENV OMNIROUTE_LOG_LEVEL=info

# Timeouts
ENV OMNIROUTE_REQUEST_TIMEOUT=300

# CORS
ENV OMNIROUTE_CORS_ORIGINS=*

# Disable external services
ENV PRICING_SYNC_ENABLED=false
ENV MODELS_DEV_ENABLED=false
ENV REDIS_URL=

# Security
ENV INITIAL_PASSWORD=ChangeMe_StrongPassword2026!

EXPOSE 10000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -sf http://localhost:10000/health || \
        curl -sf http://localhost:10000/v1/models || \
        curl -sf http://localhost:10000/api/monitoring/health || \
        exit 1

# ===== DIRECT COMMAND - No entrypoint =====
# Use 'omniroute serve' to explicitly start the HTTP server
# --host and --port ensure proper binding on Render
CMD ["sh", "-c", "echo '🚀 Starting OmniRoute on ${HOST:-0.0.0.0}:${PORT:-10000}' && omniroute serve --host ${HOST:-0.0.0.0} --port ${PORT:-10000}"]
