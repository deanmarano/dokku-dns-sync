#!/usr/bin/env bash
# Quick test runner for development

set -eo pipefail

echo "⚡ Quick DNS Plugin Test"

# Check if containers are running
if ! docker ps | grep -q dokku-local; then
    echo "🚀 Starting containers..."
    ./test-dev.sh start
else
    echo "ℹ️  Using existing containers"
fi

echo "🧪 Running tests..."
./test-dev.sh test

echo "✅ Tests complete!"