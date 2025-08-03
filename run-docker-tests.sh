#!/usr/bin/env bash
set -euo pipefail

# Simple script to run Docker-based DNS plugin tests
# Usage: ./run-docker-tests.sh [--build] [--logs]

BUILD_FLAG=""
LOGS_FLAG=""
COMPOSE_FILE="docker-compose.local.yml"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --build)
            BUILD_FLAG="--build"
            shift
            ;;
        --logs)
            LOGS_FLAG="true"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--build] [--logs]"
            echo ""
            echo "Options:"
            echo "  --build    Force rebuild of Docker images"
            echo "  --logs     Show container logs after test completion"
            echo "  --help     Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  AWS_ACCESS_KEY_ID      - AWS access key for Route53 testing"
            echo "  AWS_SECRET_ACCESS_KEY  - AWS secret key for Route53 testing"  
            echo "  AWS_DEFAULT_REGION     - AWS region (default: us-east-1)"
            echo ""
            echo "Example:"
            echo "  AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy $0 --build"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "🚀 Starting Docker-based Dokku DNS plugin tests..."
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if .env file exists and load it
if [[ -f ".env" ]]; then
    echo "📄 Loading environment variables from .env file..."
    set -a
    source .env
    set +a
elif [[ -f "../.env" ]]; then
    echo "📄 Loading environment variables from ../.env file..."
    set -a
    source ../.env
    set +a
fi

# Clean up any existing containers
echo "🧹 Cleaning up existing containers..."
docker-compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true

# Build and start the containers
echo "🏗️  Building and starting containers..."
if docker-compose -f "$COMPOSE_FILE" up $BUILD_FLAG --abort-on-container-exit; then
    echo ""
    echo "✅ Tests completed successfully!"
    
    if [[ "$LOGS_FLAG" == "true" ]]; then
        echo ""
        echo "📋 Container logs:"
        echo "===================="
        docker-compose -f "$COMPOSE_FILE" logs
    fi
else
    echo ""
    echo "❌ Tests failed!"
    
    echo ""
    echo "📋 Container logs for debugging:"
    echo "================================"
    docker-compose -f "$COMPOSE_FILE" logs
    
    # Clean up
    docker-compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true
    exit 1
fi

# Clean up
echo ""
echo "🧹 Cleaning up containers..."
docker-compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true

echo ""
echo "🎉 Docker-based testing completed!"
echo "   Your DNS plugin domain parsing fixes have been verified!"