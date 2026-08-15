# ============================================
# OmniRoute Production Docker Image
# Compatible with Railway, Railway.app, and any container platform
# ============================================

# استفاده از Node.js 24 (LTS) - نسخه پشتیبانی شده توسط OmniRoute
FROM node:24-slim AS base

# جلوگیری از interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# نصب dependencies سیستمی مورد نیاز
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    wget \
    sqlite3 \
    ca-certificates \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    git \
    procps \
    tini \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# ساخت directories مورد نیاز
RUN mkdir -p /app/data/sessions \
             /app/data/providers \
             /app/data/compression \
             /app/data/logs \
             /root/.omniroute \
    && chown -R node:node /app /root/.omniroute

# نصب OmniRoute به صورت global
RUN npm install -g omniroute@latest --production

# ایجاد non-root user (اختیاری برای امنیت)
# RUN useradd -m -u 1001 omniroute
# USER omniroute

WORKDIR /app

# کپی entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Environment variables پیش‌فرض
ENV PORT=20128 \
    HOST=[::] \
    OMNIROUTE_PORT=20128 \
    OMNIROUTE_HOST=[::] \
    OMNIROUTE_DATA_DIR=/app/data \
    OMNIROUTE_DB_PATH=/app/data/omniroute.db \
    OMNIROUTE_CONFIG_PATH=/app/data/config.json \
    NODE_OPTIONS="--max-old-space-size=384" \
    NODE_ENV=production \
    STORAGE_ENCRYPTION_KEY="" \
    OMNIROUTE_KEY_COOLDOWN=""

# Expose port
EXPOSE 20128

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:20128/v1/models || exit 1

# استفاده از tini برای signal handling بهتر
ENTRYPOINT ["/usr/bin/tini", "--"]

# اجرای entrypoint
CMD ["/app/entrypoint.sh"]
