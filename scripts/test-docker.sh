#!/usr/bin/env bash
set -euo pipefail

# Unified Docker-based DNS plugin testing script
# This is a wrapper that calls the modular integration test orchestrator
# Usage: scripts/test-docker.sh [--build] [--logs] [--direct]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR="$SCRIPT_DIR/../tests/integration/docker-orchestrator.sh"

# Check if the orchestrator exists
if [[ ! -f "$ORCHESTRATOR" ]]; then
    echo "❌ Integration test orchestrator not found: $ORCHESTRATOR"
    echo "   Make sure tests/integration/docker-orchestrator.sh exists"
    exit 1
fi

# Pass all arguments to the orchestrator
exec "$ORCHESTRATOR" "$@"