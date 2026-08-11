#!/bin/bash

# ============================================================
# OmniRoute Entrypoint Script - Railway Compatible
# FINAL VERSION - All CLI flags validated
# WITH AUTO-RESTORE FROM REMOTE BACKUP (Apexgram)
# ============================================================

set -e

echo "=========================================="
echo "🚀 OmniRoute Entrypoint Starting"
echo "=========================================="
echo "Time: $(date)"
echo ""

# ============================================================
# Print Environment Variables
# ============================================================
echo "📋 Environment Variables:"
echo "  PORT: ${PORT:-NOT SET}"
echo "  HOST: ${HOST:-NOT SET}"
echo "  OMNIROUTE_PORT: ${OMNIROUTE_PORT:-NOT SET}"
echo "  OMNIROUTE_HOST: ${OMNIROUTE_HOST:-NOT SET}"
echo "  OMNIROUTE_DATA_DIR: ${OMNIROUTE_DATA_DIR:-NOT SET}"
echo "  OMNIROUTE_DB_PATH: ${OMNIROUTE_DB_PATH:-NOT SET}"
echo "  OMNIROUTE_CONFIG_PATH: ${OMNIROUTE_CONFIG_PATH:-NOT SET}"
echo "  NODE_OPTIONS: ${NODE_OPTIONS:-NOT SET}"
echo ""

# ============================================================
# Validate Required Variables
# ============================================================
if [ -z "$PORT" ]; then
    echo "⚠️ WARNING: PORT not set, defaulting to 20128"
    export PORT=20128
fi

# CRITICAL: Always force HOST to 0.0.0.0 for Railway
if [ -z "$HOST" ] || [ "$HOST" = "[::]" ] || [ "$HOST" = "localhost" ] || [ "$HOST" = "127.0.0.1" ]; then
    echo "⚠️ HOST invalid or not set, forcing 0.0.0.0 for Railway compatibility"
    export HOST=0.0.0.0
fi

# Set OmniRoute environment variables
# OmniRoute reads these from ENV, not from CLI flags
export OMNIROUTE_PORT="${PORT}"
export OMNIROUTE_HOST="${HOST}"
export OMNIROUTE_DATA_DIR="${OMNIROUTE_DATA_DIR:-/app/data}"

echo "🎯 Final configuration:"
echo "  Will bind to: ${OMNIROUTE_HOST}:${OMNIROUTE_PORT}"
echo "  Data directory: ${OMNIROUTE_DATA_DIR}"
echo ""

# ============================================================
# Verify TLS Client Dependencies
# ============================================================
echo "🔍 Checking TLS Client dependencies..."
if [ ! -f /lib/x86_64-linux-gnu/libresolv.so.2 ] && [ ! -f /usr/lib/x86_64-linux-gnu/libresolv.so.2 ]; then
    echo "❌ ERROR: libresolv.so.2 not found!"
    exit 1
fi
echo "✅ libresolv.so.2 found"
echo ""

# ============================================================
# Create Required Directories
# ============================================================
echo "📁 Creating data directories..."
DATA_DIR="${OMNIROUTE_DATA_DIR:-/app/data}"
mkdir -p "$DATA_DIR"
mkdir -p "$DATA_DIR/sessions"
mkdir -p "$DATA_DIR/providers"
mkdir -p "$DATA_DIR/compression"
mkdir -p "$DATA_DIR/logs"

# Ensure OmniRoute home directory exists (default database location)
mkdir -p /root/.omniroute

chmod -R 755 "$DATA_DIR" 2>/dev/null || true
echo "✅ Data directories ready at: $DATA_DIR"
echo ""

# ============================================================
# 🔽 RESTORE DATABASE FROM REMOTE BACKUP (Apexgram Link)
# ============================================================
echo "=========================================="
echo "🔽 DATABASE RESTORE SECTION"
echo "=========================================="

# The direct download link from apexgram.ir
BACKUP_URL="https://dl.apexgram.ir/96389/omniroute-backup-2026-08-10T10-02-08-556Z.sqlite?hash=1b3a2c"

# Target database path (OmniRoute's default location)
DB_PATH="/root/.omniroute/storage.sqlite"

if [ -n "$BACKUP_URL" ] && [ ! -f "$DB_PATH" ]; then
    echo "⬇️  Database not found locally. Downloading backup..."
    echo "   From: $BACKUP_URL"
    echo "   To:   $DB_PATH"
    echo ""
    
    # Download with progress, following redirects (-L) and failing on HTTP errors (-f)
    if curl -L -f --progress-bar -o "$DB_PATH" "$BACKUP_URL"; then
        echo ""
        echo "✅ Backup downloaded successfully!"
        chmod 644 "$DB_PATH"
        
        # Show file info for verification
        echo "📊 File info:"
        ls -lh "$DB_PATH"
        echo ""
        
        # Create a safety backup copy
        BACKUP_COPY="/root/.omniroute/storage.restored.sqlite"
        cp "$DB_PATH" "$BACKUP_COPY"
        echo "💾 Safety copy created at: $BACKUP_COPY"
    else
        echo ""
        echo "❌ Failed to download backup!"
        echo "   Starting with fresh database instead..."
        rm -f "$DB_PATH"
    fi
elif [ -f "$DB_PATH" ]; then
    echo "📦 Existing database found, skipping restore"
    ls -lh "$DB_PATH"
else
    echo "ℹ️  No backup URL configured"
fi

# Also copy to alternate location if DATA_DIR is different
ALT_DB_PATH="${DATA_DIR}/storage.sqlite"
if [ -f "$DB_PATH" ] && [ "$DB_PATH" != "$ALT_DB_PATH" ]; then
    cp "$DB_PATH" "$ALT_DB_PATH" 2>/dev/null || true
    echo "📋 Database also copied to: $ALT_DB_PATH"
fi

echo ""
echo "=========================================="
echo ""

# ============================================================
# Verify OmniRoute Installation
# ============================================================
echo "🔍 Checking OmniRoute installation..."
if ! command -v omniroute &> /dev/null; then
    echo "❌ ERROR: omniroute command not found!"
    exit 1
fi

echo "✅ OmniRoute found at: $(which omniroute)"
echo "✅ OmniRoute version:"
omniroute --version 2>&1 | head -5 || true
echo ""

# ============================================================
# Build Command Arguments
# CRITICAL: omniroute serve ONLY supports these flags:
#   --port, --no-open, --log, --daemon, --tls-cert, --tls-key,
#   --tray, --no-recovery, --max-restarts
#
# HOST and DATA_DIR are read from environment variables only!
# ============================================================
echo "🛠️ Building startup command..."

OMNI_ARGS=()
OMNI_ARGS+=("--port" "${OMNIROUTE_PORT}")
OMNI_ARGS+=("--no-open")
OMNI_ARGS+=("--log")

# DO NOT add --host or --data-dir! They cause "unknown option" errors!
# HOST is read from environment variable HOST
# DATA_DIR is read from environment variable OMNIROUTE_DATA_DIR

echo "✅ Command: HOST=${HOST} OMNIROUTE_DATA_DIR=${OMNIROUTE_DATA_DIR} omniroute serve ${OMNI_ARGS[*]}"
echo ""

# ============================================================
# Graceful Shutdown Handler
# ============================================================
OMNI_PID=""

cleanup() {
    echo ""
    echo "=========================================="
    echo "🛑 Shutting down OmniRoute..."
    echo "=========================================="
    
    if [ -n "$OMNI_PID" ] && kill -0 "$OMNI_PID" 2>/dev/null; then
        echo "Sending SIGTERM to OmniRoute (PID: $OMNI_PID)..."
        kill -TERM "$OMNI_PID" 2>/dev/null || true
        
        for i in {1..30}; do
            if ! kill -0 "$OMNI_PID" 2>/dev/null; then
                echo "✅ OmniRoute stopped gracefully"
                break
            fi
            sleep 1
        done
        
        if kill -0 "$OMNI_PID" 2>/dev/null; then
            echo "⚠️ OmniRoute did not stop gracefully, forcing..."
            kill -KILL "$OMNI_PID" 2>/dev/null || true
        fi
    fi
    
    echo "👋 Shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT SIGHUP EXIT

# ============================================================
# Start OmniRoute
# ============================================================
echo "=========================================="
echo "🚀 Starting OmniRoute..."
echo "=========================================="
echo "Binding to: ${OMNIROUTE_HOST}:${OMNIROUTE_PORT}"
echo "Data directory: ${OMNIROUTE_DATA_DIR}"
echo ""

# Start OmniRoute in background
# HOST and OMNIROUTE_DATA_DIR are passed via environment variables
omniroute serve "${OMNI_ARGS[@]}" &
OMNI_PID=$!

echo "✅ OmniRoute started with PID: $OMNI_PID"
echo ""

# ============================================================
# Wait for OmniRoute to be ready
# ============================================================
echo "⏳ Waiting for OmniRoute to be ready..."
MAX_WAIT=180
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    if ! kill -0 "$OMNI_PID" 2>/dev/null; then
        echo "❌ ERROR: OmniRoute process died!"
        exit 1
    fi
    
    # PRIMARY: Check /v1/models endpoint (Railway Health Check Path)
    if curl -sf "http://127.0.0.1:${OMNIROUTE_PORT}/v1/models" > /dev/null 2>&1; then
        echo "✅ OmniRoute is ready! (waited ${WAITED}s)"
        break
    fi
    
    # FALLBACK: Check /api/monitoring/health (official OmniRoute health endpoint)
    if curl -sf "http://127.0.0.1:${OMNIROUTE_PORT}/api/monitoring/health" > /dev/null 2>&1; then
        echo "✅ OmniRoute is ready! (waited ${WAITED}s)"
        break
    fi
    
    # FALLBACK 2: Check root dashboard
    if curl -sf "http://127.0.0.1:${OMNIROUTE_PORT}/" > /dev/null 2>&1; then
        echo "✅ OmniRoute is ready! (waited ${WAITED}s)"
        break
    fi
    
    sleep 3
    WAITED=$((WAITED + 3))
    
    if [ $((WAITED % 30)) -eq 0 ]; then
        echo "⏳ Still waiting... (${WAITED}s / ${MAX_WAIT}s)"
    fi
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "⚠️ WARNING: OmniRoute did not become ready within ${MAX_WAIT}s"
    echo "Continuing anyway - service might still be starting..."
fi

echo ""

# ============================================================
# Print Access Information
# ============================================================
echo "=========================================="
echo "✅ OmniRoute is running!"
echo "=========================================="
echo "PID: $OMNI_PID"
echo "Host: ${OMNIROUTE_HOST}"
echo "Port: ${OMNIROUTE_PORT}"
echo "Data: ${OMNIROUTE_DATA_DIR}"
echo ""
echo "Available endpoints:"
echo "  - Dashboard: http://${OMNIROUTE_HOST}:${OMNIROUTE_PORT}/"
echo "  - API: http://${OMNIROUTE_HOST}:${OMNIROUTE_PORT}/v1"
echo "  - Models (Railway Health Check): http://${OMNIROUTE_HOST}:${OMNIROUTE_PORT}/v1/models"
echo "  - Health (Official): http://${OMNIROUTE_HOST}:${OMNIROUTE_PORT}/api/monitoring/health"
echo ""
echo "=========================================="
echo ""

# ============================================================
# Wait for OmniRoute process
# ============================================================
wait "$OMNI_PID" 2>/dev/null || EXIT_CODE=$?

if [ "${EXIT_CODE:-0}" -ne 0 ]; then
    echo "❌ OmniRoute exited with code: ${EXIT_CODE:-unknown}"
    exit ${EXIT_CODE:-1}
fi
