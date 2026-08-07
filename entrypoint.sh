#!/bin/bash

# ============================================================
# OmniRoute Entrypoint Script
# Ensures proper port binding and environment configuration
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
echo "  INITIAL_PASSWORD: $([ -n "$INITIAL_PASSWORD" ] && echo "SET (length: ${#INITIAL_PASSWORD})" || echo "NOT SET")"
echo ""

# ============================================================
# Validate Required Variables
# ============================================================
if [ -z "$PORT" ]; then
    echo "⚠️ WARNING: PORT not set, defaulting to 10000"
    export PORT=10000
fi

if [ -z "$HOST" ]; then
    echo "⚠️ WARNING: HOST not set, defaulting to 0.0.0.0"
    export HOST=0.0.0.0
fi

# Ensure OmniRoute uses the same port/host
export OMNIROUTE_PORT="${PORT}"
export OMNIROUTE_HOST="${HOST}"

echo "🎯 Final binding configuration:"
echo "  Will bind to: ${OMNIROUTE_HOST}:${OMNIROUTE_PORT}"
echo ""

# ============================================================
# Verify TLS Client Dependencies
# ============================================================
echo "🔍 Checking TLS Client dependencies..."
if [ ! -f /lib/x86_64-linux-gnu/libresolv.so.2 ]; then
    echo "❌ ERROR: libresolv.so.2 not found!"
    echo "This is required for TLS impersonation (chatgpt-web, claude-web, etc.)"
    exit 1
fi
echo "✅ libresolv.so.2 found"

# Check if tls-client binary exists
TLS_CLIENT_PATH="/root/.omniroute/tls-client/bin"
if [ -d "$TLS_CLIENT_PATH" ]; then
    echo "✅ TLS client directory exists"
    ls -la "$TLS_CLIENT_PATH" 2>/dev/null || true
fi

# ============================================================
# Create Required Directories
# ============================================================
echo ""
echo "📁 Creating data directories..."
DATA_DIR="${OMNIROUTE_DATA_DIR:-/app/data}"
mkdir -p "$DATA_DIR"
mkdir -p "$DATA_DIR/sessions"
mkdir -p "$DATA_DIR/providers"
mkdir -p "$DATA_DIR/compression"
mkdir -p "$DATA_DIR/logs"

# Set permissions
chmod -R 755 "$DATA_DIR" 2>/dev/null || true
echo "✅ Data directories ready at: $DATA_DIR"
echo ""

# ============================================================
# Verify OmniRoute Installation
# ============================================================
echo "🔍 Checking OmniRoute installation..."
if ! command -v omniroute &> /dev/null; then
    echo "❌ ERROR: omniroute command not found!"
    echo "Attempting emergency install..."
    npm install -g omniroute --legacy-peer-deps
fi

echo "✅ OmniRoute found at: $(which omniroute)"
echo "✅ OmniRoute version:"
omniroute --version 2>&1 | head -5 || echo "Version check failed but continuing..."
echo ""

# ============================================================
# Pre-flight Checks
# ============================================================
echo "🔎 Pre-flight checks..."

# Check if port is already in use
if command -v ss &> /dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":${PORT}"; then
        echo "⚠️ WARNING: Port ${PORT} is already in use!"
        ss -tlnp 2>/dev/null | grep ":${PORT}" || true
    fi
elif command -v netstat &> /dev/null; then
    if netstat -tlnp 2>/dev/null | grep -q ":${PORT}"; then
        echo "⚠️ WARNING: Port ${PORT} is already in use!"
        netstat -tlnp 2>/dev/null | grep ":${PORT}" || true
    fi
fi

echo "✅ Pre-flight checks complete"
echo ""

# ============================================================
# Build Command Arguments
# ============================================================
echo "🛠️ Building startup command..."

OMNI_ARGS=()
OMNI_ARGS+=("--host" "${OMNIROUTE_HOST}")
OMNI_ARGS+=("--port" "${OMNIROUTE_PORT}")

if [ -n "$OMNIROUTE_DATA_DIR" ]; then
    OMNI_ARGS+=("--data-dir" "$OMNIROUTE_DATA_DIR")
fi

OMNI_ARGS+=("--no-open")
OMNI_ARGS+=("--log")

echo "✅ Command will be: omniroute serve ${OMNI_ARGS[*]}"
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
omniroute serve "${OMNI_ARGS[@]}" &
OMNI_PID=$!

echo "✅ OmniRoute started with PID: $OMNI_PID"
echo ""

# ============================================================
# Wait for OmniRoute to be ready
# ============================================================
echo "⏳ Waiting for OmniRoute to be ready..."
MAX_WAIT=120
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
    if ! kill -0 "$OMNI_PID" 2>/dev/null; then
        echo "❌ ERROR: OmniRoute process died!"
        exit 1
    fi
    
    if curl -sf "http://${OMNIROUTE_HOST}:${OMNIROUTE_PORT}/health" > /dev/null 2>&1; then
        echo "✅ OmniRoute is ready! (waited ${WAITED}s)"
        break
    fi
    
    if curl -sf "http://${OMNIROUTE_HOST}:${OMNIROUTE_PORT}/v1/models" > /dev/null 2>&1; then
        echo "✅ OmniRoute is ready! (waited ${WAITED}s)"
        break
    fi
    
    sleep 2
    WAITED=$((WAITED + 2))
    
    if [ $((WAITED % 20)) -eq 0 ]; then
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
echo ""
echo "Available endpoints:"
echo "  - Dashboard: http://${OMNIROUTE_HOST}:${OMNIROUTE_PORT}/"
echo "  - API: http://${OMNIROUTE_HOST}:${OMNIROUTE_PORT}/v1"
echo "  - Health: http://${OMNIROUTE_HOST}:${OMNIROUTE_PORT}/health"
echo "  - Models: http://${OMNIROUTE_HOST}:${OMNIROUTE_PORT}/v1/models"
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
