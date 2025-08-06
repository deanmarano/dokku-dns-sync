#!/usr/bin/env bash
# Fast development testing with persistent containers

set -eo pipefail

CONTAINER_NAME="dokku-dns-dev"

usage() {
    echo "Usage: $0 [start|stop|test|clean]"
    echo ""
    echo "Commands:"
    echo "  start  - Start persistent containers for development"
    echo "  test   - Run tests against running containers"
    echo "  stop   - Stop persistent containers"
    echo "  clean  - Stop and remove all containers/volumes"
    echo ""
    echo "Fast development workflow:"
    echo "  ./test-dev.sh start   # Start containers once"
    echo "  ./test-dev.sh test    # Run tests quickly (repeatable)"
    echo "  ./test-dev.sh stop    # Stop when done"
}

start_containers() {
    echo "🚀 Starting persistent development containers..."
    
    if docker ps | grep -q "$CONTAINER_NAME"; then
        echo "ℹ️  Containers already running"
        return 0
    fi
    
    # Start containers in detached mode
    docker-compose -f docker-compose.local.yml up -d
    
    echo "⏳ Waiting for containers to initialize..."
    sleep 15
    
    # Wait for Dokku to be ready
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker exec dokku-local echo "ready" >/dev/null 2>&1; then
            echo "✅ Containers ready for testing"
            return 0
        fi
        ((attempt++))
        echo "   Waiting... ($attempt/$max_attempts)"
        sleep 2
    done
    
    echo "❌ Containers failed to start properly"
    return 1
}

run_tests() {
    echo "🧪 Running tests against persistent containers..."
    
    if ! docker ps --format "{{.Names}}" | grep -q "^dokku-local$"; then
        echo "❌ Containers not running. Start them first with: $0 start"
        return 1
    fi
    
    # Run tests directly without container setup/teardown
    docker exec dokku-local bash -c "
        cd /var/lib/dokku/plugins/available/dns
        
        # Run integration tests
        echo '🧪 Running integration tests...'
        if [[ -f tests/integration/dns-integration-tests.sh ]]; then
            bash tests/integration/dns-integration-tests.sh
        else
            echo '❌ Integration test file not found'
            ls -la tests/ 2>/dev/null || echo 'No tests directory'
        fi
    "
}

stop_containers() {
    echo "🛑 Stopping development containers..."
    docker-compose -f docker-compose.local.yml stop
    echo "✅ Containers stopped"
}

clean_containers() {
    echo "🧹 Cleaning up all containers and volumes..."
    docker-compose -f docker-compose.local.yml down -v
    echo "✅ Cleanup complete"
}

case "${1:-}" in
    start)
        start_containers
        ;;
    test)
        run_tests
        ;;
    stop)
        stop_containers
        ;;
    clean)
        clean_containers
        ;;
    ""|help|-h|--help)
        usage
        ;;
    *)
        echo "❌ Unknown command: $1"
        usage
        exit 1
        ;;
esac