#!/usr/bin/env bash
set -euo pipefail

# Wait for Dokku container to be ready and run tests
DOKKU_CONTAINER="${DOKKU_CONTAINER:-dokku-local}"
MAX_WAIT=300  # 5 minutes
WAIT_INTERVAL=5

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1: $2"
}

log "INFO" "Waiting for Dokku container to be ready..."

# Wait for Dokku container to respond via Docker
for i in $(seq 1 $((MAX_WAIT / WAIT_INTERVAL))); do
    if docker exec "$DOKKU_CONTAINER" echo "Container ready" >/dev/null 2>&1; then
        log "INFO" "Dokku container is responding: $DOKKU_CONTAINER"
        break
    fi
    
    if [ "$i" -eq $((MAX_WAIT / WAIT_INTERVAL)) ]; then
        log "ERROR" "Timeout waiting for Dokku container to be ready"
        exit 1
    fi
    
    log "INFO" "Waiting... (attempt $i/$((MAX_WAIT / WAIT_INTERVAL)))"
    sleep $WAIT_INTERVAL
done

# Give Dokku a few more seconds to fully initialize
log "INFO" "Waiting additional 10 seconds for Dokku to fully initialize..."
sleep 10

log "INFO" "Starting Docker-based Dokku DNS plugin tests..."

# Run the Docker-specific test script in direct mode (containers already running)
exec /test-docker.sh --direct