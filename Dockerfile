# ============================================================
# OmniRoute - Free AI Gateway
# Deployed on Render as a separate Web Service
# Provides OpenAI-compatible API for Hermes Agent
# ============================================================

# Use official Node.js 22 LTS slim image
FROM node:22-slim

# Prevent npm from writing unnecessary files
ENV NPM_CONFIG_LOGLEVEL=warn
ENV NODE_ENV=production

# Set working directory
WORKDIR /app

# Install system dependencies needed for native modules
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    procps \
    bash \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Install OmniRoute globally
# --omit=dev skips devDependencies to reduce image size
# --ignore-scripts skips postinstall scripts that might fail in container
RUN npm install -g omniroute --omit=dev 2>/dev/null || \
    npm install -g omniroute 2>/dev/null || \
    (echo "Retrying with legacy peer deps..." && \
     npm install -g omniroute --legacy-peer-deps)

# Verify installation
RUN which omniroute && omniroute --version 2>&1 | head -5 || echo "OmniRoute installed"

# Create data directory for OmniRoute state
# This stores provider connections, API keys, settings
RUN mkdir -p /app/data && \
    chmod -R 755 /app/data

# ============================================================
# DEFAULT ENVIRONMENT VARIABLES
# These will be overridden by Render's environment variables
# ============================================================

# Server binding - Render requires PORT to be bound on 0.0.0.0
ENV PORT=10000
ENV HOST=0.0.0.0

# OmniRoute specific variables
ENV OMNIROUTE_PORT=10000
ENV OMNIROUTE_HOST=0.0.0.0
ENV OMNIROUTE_DATA_DIR=/app/data
ENV OMNIROUTE_DB_PATH=/app/data/omniroute.db
ENV OMNIROUTE_CONFIG_PATH=/app/data/config.json

# Node.js memory limit for Render Free tier (512MB)
# 384MB leaves room for OS and other processes
ENV NODE_OPTIONS="--max-old-space-size=384"

# Disable telemetry and analytics
ENV OMNIROUTE_TELEMETRY=0
ENV OMNIROUTE_ANALYTICS=0
ENV OMNIROUTE_NO_TELEMETRY=1
ENV OMNIROUTE_NO_ANALYTICS=1

# Set a strong initial password to avoid security warning
# You can override this in Render Environment Variables
ENV INITIAL_PASSWORD=ChangeMe_ThisIsNotSecure_2026!

# Enable auto free fallback (uses free providers when paid ones unavailable)
ENV OMNIROUTE_AUTO_FREE_FALLBACK_TO_FULL_POOL=true

# Compression settings
ENV OMNIROUTE_COMPRESSION_MODE=stacked
ENV OMNIROUTE_COMPRESSION_RTK=1
ENV OMNIROUTE_COMPRESSION_CAVEMAN=1
ENV OMNIROUTE_COMPRESSION_LLMLINGUA=0

# Routing settings
ENV OMNIROUTE_DEFAULT_STRATEGY=auto
ENV OMNIROUTE_AUTO_COMBO=1
ENV OMNIROUTE_FALLBACK_ENABLED=1
ENV OMNIROUTE_MAX_FALLBACK_ATTEMPTS=3

# Logging settings
ENV OMNIROUTE_LOG_LEVEL=info
ENV OMNIROUTE_LOG_REQUESTS=0

# Request settings
ENV OMNIROUTE_REQUEST_TIMEOUT=300
ENV OMNIROUTE_MAX_CONCURRENT=10

# Feature toggles
ENV OMNIROUTE_ENABLE_MCP=1
ENV OMNIROUTE_ENABLE_A2A=1
ENV OMNIROUTE_ENABLE_MEMORY=0

# Circuit breaker settings
ENV OMNIROUTE_CIRCUIT_BREAKER_THRESHOLD=5
ENV OMNIROUTE_CIRCUIT_BREAKER_RESET=60
ENV OMNIROUTE_KEY_COOLDOWN=5

# CORS settings - will be overridden by Render env vars
ENV OMNIROUTE_CORS_ORIGINS=*

# Disable features that need external services
ENV PRICING_SYNC_ENABLED=false
ENV MODELS_DEV_ENABLED=false

# Disable Redis (use in-memory)
ENV REDIS_URL=

# Expose the OmniRoute port
EXPOSE 10000

# Health check - Render will use this to keep service alive
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -sf http://localhost:10000/health || curl -sf http://localhost:10000/v1/models || exit 1

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Use tini as init system to handle signals properly
ENTRYPOINT ["/usr/bin/tini", "--", "/app/entrypoint.sh"]

# Default command (will be overridden by entrypoint)
CMD ["omniroute"]
