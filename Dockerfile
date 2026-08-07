FROM node:22-alpine

RUN echo "Final: 2026-08-07-no-host-flag-v6"

WORKDIR /app

RUN apk add --no-cache curl

RUN npm install -g omniroute --omit=dev --ignore-scripts 2>/dev/null || \
    npm install -g omniroute --legacy-peer-deps --ignore-scripts

ENV PORT=10000
ENV HOST=0.0.0.0
ENV NODE_OPTIONS="--max-old-space-size=256"
ENV OMNIROUTE_DATA_DIR=/app/data
ENV INITIAL_PASSWORD=ChangeMe2026
ENV OMNIROUTE_TELEMETRY=0
ENV OMNIROUTE_ANALYTICS=0
ENV OMNIROUTE_COMPRESSION_MODE=off
ENV OMNIROUTE_COMPRESSION_LLMLINGUA=0
ENV OMNIROUTE_ENABLE_MCP=0
ENV OMNIROUTE_ENABLE_A2A=0
ENV OMNIROUTE_ENABLE_MEMORY=0
ENV OMNIROUTE_LOG_LEVEL=warn
ENV OMNIROUTE_MAX_CONCURRENT=2
ENV PRICING_SYNC_ENABLED=false
ENV MODELS_DEV_ENABLED=false
ENV REDIS_URL=

RUN mkdir -p /app/data

EXPOSE 10000

HEALTHCHECK --interval=60s --timeout=30s --start-period=180s --retries=3 \
    CMD curl -sf http://localhost:10000/health || exit 1

# فقط --port، بدون --host
CMD ["sh", "-c", "omniroute serve --port ${PORT:-10000} --no-open --log"]
