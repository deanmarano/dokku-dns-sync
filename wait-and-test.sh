#!/usr/bin/env bash
set -euo pipefail

# Wait for Dokku container to be ready and run tests
DOKKU_HOST="${DOKKU_HOST:-dokku}"
DOKKU_SSH_PORT="${DOKKU_SSH_PORT:-22}"
DOKKU_USER="${DOKKU_USER:-dokku}"
MAX_WAIT=300  # 5 minutes
WAIT_INTERVAL=5

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1: $2"
}

log "INFO" "Waiting for Dokku container to be ready..."

# Wait for Dokku container to respond
for i in $(seq 1 $((MAX_WAIT / WAIT_INTERVAL))); do
    if nc -z "$DOKKU_HOST" "$DOKKU_SSH_PORT" 2>/dev/null; then
        log "INFO" "Dokku container is responding on port $DOKKU_SSH_PORT"
        break
    fi
    
    if [ $i -eq $((MAX_WAIT / WAIT_INTERVAL)) ]; then
        log "ERROR" "Timeout waiting for Dokku container to be ready"
        exit 1
    fi
    
    log "INFO" "Waiting... (attempt $i/$((MAX_WAIT / WAIT_INTERVAL)))"
    sleep $WAIT_INTERVAL
done

# Give Dokku a few more seconds to fully initialize
log "INFO" "Waiting additional 10 seconds for Dokku to fully initialize..."
sleep 10

# Set up SSH key if needed (for container-to-container communication)
if [ ! -f ~/.ssh/id_rsa ]; then
    log "INFO" "Generating SSH key for container communication..."
    mkdir -p ~/.ssh
    ssh-keygen -t rsa -f ~/.ssh/id_rsa -N "" -q
    chmod 600 ~/.ssh/id_rsa
    chmod 700 ~/.ssh
fi

# Add Dokku host to known hosts
log "INFO" "Adding Dokku host to known hosts..."
ssh-keyscan -p "$DOKKU_SSH_PORT" "$DOKKU_HOST" >> ~/.ssh/known_hosts 2>/dev/null || true

log "INFO" "Starting Docker-based Dokku DNS plugin tests..."

# Run the Docker-specific test script in direct mode (containers already running)
exec /test-docker.sh --direct