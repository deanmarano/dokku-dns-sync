#!/usr/bin/env bash
set -euo pipefail

# Run BATS tests directly inside the Docker container
echo "🧪 Running BATS tests directly inside Docker container..."

# Check if Docker containers are running
if ! docker exec dokku-local dokku version >/dev/null 2>&1; then
    echo "❌ Dokku Docker container not running. Start with: docker-compose -f docker-compose.local.yml up -d"
    exit 1
fi

# Install and run tests inside the container
docker exec dokku-local bash -c '
    # Install bats if not present
    if ! command -v bats >/dev/null 2>&1; then
        echo "Installing BATS in container..."
        apt-get update -qq
        apt-get install -y git
        git clone https://github.com/bats-core/bats-core.git /tmp/bats-core
        cd /tmp/bats-core
        ./install.sh /usr/local
        rm -rf /tmp/bats-core
    fi
    
    # Install the DNS plugin if not already done
    if ! dokku plugin:list | grep -q dns; then
        echo "Installing DNS plugin..."
        rm -rf /var/lib/dokku/plugins/available/dns
        cp -r /tmp/dokku-dns /var/lib/dokku/plugins/available/dns
        chown -R dokku:dokku /var/lib/dokku/plugins/available/dns
        dokku plugin:enable dns
        /var/lib/dokku/plugins/available/dns/install || echo "Install script completed with warnings"
    fi
    
    # Set up environment for tests - use real Dokku installation
    export DOKKU_LIB_ROOT="/var/lib/dokku"
    export PATH="$PATH:$DOKKU_LIB_ROOT/plugins/available/dns/subcommands"
    
    # Create test directory and copy tests
    mkdir -p /tmp/dns-tests
    cp -r /tmp/dokku-dns/tests/* /tmp/dns-tests/
    # Copy additional essential plugin files for tests
    cp /tmp/dokku-dns/config /tmp/dns-tests/
    cp /tmp/dokku-dns/functions /tmp/dns-tests/
    cp /tmp/dokku-dns/commands /tmp/dns-tests/
    cd /tmp/dns-tests
    
    # Verify DNS plugin is available
    echo "Checking DNS plugin availability..."
    dokku dns:help >/dev/null 2>&1 && echo "✓ DNS plugin commands available" || echo "✗ DNS plugin commands not available"
    
    # Create comprehensive test apps and domains for all tests
    echo "Setting up test apps and domains..."
    
    # Main test apps
    dokku apps:create testapp >/dev/null 2>&1 || echo "testapp already exists"
    dokku apps:create nextcloud >/dev/null 2>&1 || echo "nextcloud already exists"
    dokku apps:create my-app >/dev/null 2>&1 || echo "my-app already exists"
    dokku apps:create empty-app >/dev/null 2>&1 || echo "empty-app already exists"
    dokku apps:create single-app >/dev/null 2>&1 || echo "single-app already exists"
    
    # Add domains for various test scenarios
    dokku domains:add testapp example.com >/dev/null 2>&1 || true
    dokku domains:add testapp test.example.com >/dev/null 2>&1 || true
    dokku domains:add nextcloud api.example.com >/dev/null 2>&1 || true
    dokku domains:add my-app example.com >/dev/null 2>&1 || true
    dokku domains:add my-app api.example.com >/dev/null 2>&1 || true
    dokku domains:add single-app single.example.com >/dev/null 2>&1 || true
    # empty-app intentionally gets no domains
    
    # Configure AWS provider for tests that need it
    dokku dns:configure aws >/dev/null 2>&1 || true
    
    # Fix permissions for DNS data directory
    chmod 777 /var/lib/dokku/data/dns 2>/dev/null || true
    
    echo "✓ Test environment setup complete"
    
    echo "Running BATS tests..."
    bats *.bats
'

echo "✅ BATS tests completed"