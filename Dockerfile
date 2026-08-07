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
    && rm -rf /var/lib/apt/lists/*

# Install OmniRoute globally
# --omit=dev skips devDependencies to reduce image size
# --ignore-scripts skips postinstall scripts that might fail in container
RUN npm install -g omniroute --omit=dev 2>/dev/null || \
    npm install -g omniroute 2>/dev/null || \
    (echo "Retrying with legacy peer deps..." && \
     npm install -g omniroute --legacy-peer-deps)

# Create data directory for OmniRoute state
# This stores provider connections, API keys, settings
RUN mkdir -p /app/data

# Set environment variables
ENV PORT=20128
ENV HOST=0.0.0.0
ENV OMNIROUTE_DATA_DIR=/app/data
ENV OMNIROUTE_HOST=0.0.0.0
ENV OMNIROUTE_PORT=20128

# Limit Node.js memory usage for Render Free tier (512MB)
# This prevents OOM kills while still allowing OmniRoute to function
ENV NODE_OPTIONS="--max-old-space-size=384"

# Disable telemetry if available
ENV OMNIROUTE_TELEMETRY=0
ENV OMNIROUTE_ANALYTICS=0

# Enable persistent storage path
ENV OMNIROUTE_DB_PATH=/app/data/omniroute.db
ENV OMNIROUTE_CONFIG_PATH=/app/data/config.json

# Expose the OmniRoute port
EXPOSE 20128

# Health check - Render will use this to keep service alive
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -sf http://localhost:20128/health || exit 1

# Start OmniRoute
# The 'omniroute' command starts the gateway + dashboard on PORT
CMD ["omniroute"]
