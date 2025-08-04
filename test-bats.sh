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
    
    # Set up environment for tests
    export DOKKU_LIB_ROOT="/var/lib/dokku"
    export PATH="$PATH:$DOKKU_LIB_ROOT/plugins/available/dns/subcommands"
    
    # Create test directory and copy tests
    mkdir -p /tmp/dns-tests
    cp -r /tmp/dokku-dns/tests/* /tmp/dns-tests/
    cd /tmp/dns-tests
    
    # Update test helper to use local dokku commands (no SSH)
    sed -i "s/dokku /\/usr\/local\/bin\/dokku /g" *.bats test_helper.bash
    
    echo "Running BATS tests..."
    bats *.bats
'

echo "✅ BATS tests completed"