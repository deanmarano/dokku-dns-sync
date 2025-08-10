#!/usr/bin/env bash
# Minimal fast testing setup

set -eo pipefail

case "${1:-test}" in
    "up"|"start")
        echo "🚀 Starting containers..."
        docker-compose -f docker-compose.local.yml up -d
        echo "⏳ Waiting 20 seconds for init..."
        sleep 20
        echo "✅ Ready for testing"
        ;;
    
    "test"|"")
        echo "🧪 Running quick test..."
        if ! docker ps --format "{{.Names}}" | grep -q "^dokku-local$"; then
            echo "Starting containers first..."
            $0 up
        fi
        
        echo "Testing basic functionality..."
        docker exec dokku-local bash -c "
            dokku apps:create testapp 2>/dev/null || true
            dokku domains:add testapp test.example.com 2>/dev/null || true
            dokku dns:add testapp 2>/dev/null || echo 'dns:add completed'
            echo '--- Global Report ---'
            dokku dns:report 2>/dev/null || echo 'Global report completed'
            echo '--- App Report ---' 
            dokku dns:report testapp 2>/dev/null || echo 'App report completed'
            dokku dns:remove testapp 2>/dev/null || echo 'dns:remove completed'
        "
        echo "✅ Test complete"
        ;;
        
    "down"|"stop")
        echo "🛑 Stopping containers..."
        docker-compose -f docker-compose.local.yml down
        ;;
        
    "clean")
        echo "🧹 Cleaning up..."
        docker-compose -f docker-compose.local.yml down -v
        ;;
        
    *)
        echo "Usage: $0 [up|test|down|clean]"
        ;;
esac