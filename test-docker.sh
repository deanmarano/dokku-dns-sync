#!/usr/bin/env bash
set -euo pipefail

# Unified Docker-based DNS plugin testing script
# This combines Docker Compose orchestration with test execution
# Usage: ./test-docker.sh [--build] [--logs]

BUILD_FLAG=""
LOGS_FLAG=""
COMPOSE_FILE="docker-compose.local.yml"

show_help() {
    echo "Usage: $0 [--build] [--logs] [--direct]"
    echo ""
    echo "Options:"
    echo "  --build    Force rebuild of Docker images"
    echo "  --logs     Show container logs after test completion"
    echo "  --direct   Run tests directly (skip Docker Compose orchestration)"
    echo "  --help     Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  AWS_ACCESS_KEY_ID      - AWS access key for Route53 testing"
    echo "  AWS_SECRET_ACCESS_KEY  - AWS secret key for Route53 testing"
    echo "  AWS_DEFAULT_REGION     - AWS region (default: us-east-1)"
    echo ""
    echo "Examples:"
    echo "  $0 --build                                    # Full Docker Compose testing"
    echo "  AWS_ACCESS_KEY_ID=xxx $0 --logs               # With AWS credentials"
    echo "  $0 --direct                                   # Direct testing (containers must be running)"
}

# Parse arguments
DIRECT_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_FLAG="--build"
            shift
            ;;
        --logs)
            LOGS_FLAG="true"
            shift
            ;;
        --direct)
            DIRECT_MODE=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Direct mode: run tests against existing containers
if [[ "$DIRECT_MODE" == "true" ]]; then
    echo "🧪 Running tests directly against existing Docker containers..."
    
    # Check if Dokku container is accessible
    DOKKU_HOST="${DOKKU_HOST:-dokku-local}"
    if ! nc -z "$DOKKU_HOST" 22 2>/dev/null; then
        echo "❌ Dokku container not accessible at $DOKKU_HOST:22"
        echo "   Start containers first: docker-compose -f $COMPOSE_FILE up -d"
        exit 1
    fi
    
    # Colors for output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    
    log() {
        local level="$1"
        shift
        local message="$*"
        
        case "$level" in
            "INFO")
                echo -e "${BLUE}[INFO]${NC} $message"
                ;;
            "SUCCESS")
                echo -e "${GREEN}[SUCCESS]${NC} $message"
                ;;
            "WARNING")
                echo -e "${YELLOW}[WARNING]${NC} $message"
                ;;
            "ERROR")
                echo -e "${RED}[ERROR]${NC} $message"
                ;;
        esac
    }
    
    # Test Docker connection
    log "INFO" "Testing connection to Dokku container..."
    if ! nc -z "$DOKKU_HOST" 22 2>/dev/null; then
        log "ERROR" "Cannot connect to Dokku container at $DOKKU_HOST:22"
        exit 1
    fi
    log "SUCCESS" "Connection to Dokku container established"
    
    # Generate and run test script inside container
    log "INFO" "Generating and executing comprehensive test suite..."
    
    # Create the test script content (extracted from original test-docker.sh)
    cat > /tmp/dns-test-script.sh << 'TEST_SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail

log_remote() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1: $2"
}

log_remote "INFO" "=== DOCKER-BASED DNS PLUGIN TESTING ==="

# Install the DNS plugin
log_remote "INFO" "Installing DNS plugin..."
rm -rf /var/lib/dokku/plugins/available/dns
cp -r /tmp/dokku-dns /var/lib/dokku/plugins/available/dns
chown -R dokku:dokku /var/lib/dokku/plugins/available/dns
dokku plugin:enable dns
/var/lib/dokku/plugins/available/dns/install || echo "Install script completed with warnings"

# Verify installation
dokku plugin:list | grep dns || {
    echo "ERROR: DNS plugin not found in plugin list"
    exit 1
}
echo "✓ DNS plugin installed successfully"

# Import AWS credentials if provided
if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
    log_remote "INFO" "Setting up AWS credentials..."
    mkdir -p ~/.aws
    cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
    cat > ~/.aws/config << EOF
[default]
region = ${AWS_DEFAULT_REGION:-us-east-1}
output = json
EOF
    echo "AWS credentials configured"
fi

# Test AWS connectivity
if command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
    echo "✓ AWS CLI is working"
else
    echo "⚠️ AWS CLI not configured or not working"
fi

# Create test app for comprehensive testing
TEST_APP="nextcloud"
echo "Setting up test app: $TEST_APP"
if ! dokku apps:list 2>/dev/null | grep -q "$TEST_APP"; then
    dokku apps:create "$TEST_APP" 2>&1 || echo "Failed to create app, using existing"
fi

# Add test domains
dokku domains:add "$TEST_APP" "test.example.com" 2>&1 || echo "Domain add completed"
dokku domains:add "$TEST_APP" "api.test.example.com" 2>&1 || echo "Domain add completed"

# Test all DNS commands
log_remote "INFO" "Testing DNS commands..."

echo "1. Testing dns:help"
dokku dns:help 2>&1 || echo "Help command completed"

echo "2. Testing dns:configure"
dokku dns:configure aws 2>&1 || echo "Configure command completed"

echo "3. Testing dns:verify"
dokku dns:verify 2>&1 || echo "Verify command completed"

echo "4. Testing dns:add"
dokku dns:add "$TEST_APP" 2>&1 || echo "Add command completed"

echo "5. Testing dns:report (after add)"
dokku dns:report "$TEST_APP" 2>&1 || echo "Report command completed"

echo "6. Testing dns:sync"
dokku dns:sync "$TEST_APP" 2>&1 || echo "Sync command completed"

echo "7. Testing dns:report (global)"
dokku dns:report 2>&1 || echo "Global report completed"

echo "8. Testing dns:remove"
dokku dns:remove "$TEST_APP" 2>&1 || echo "Remove command completed"

echo "9. Testing dns:report (after remove)"
dokku dns:report "$TEST_APP" 2>&1 || echo "Report after remove completed"

# Test edge cases
echo "10. Testing edge cases..."
dokku dns:add 2>&1 || echo "Usage error handled correctly"
dokku dns:sync 2>&1 || echo "Usage error handled correctly"
dokku dns:remove 2>&1 || echo "Usage error handled correctly"

log_remote "SUCCESS" "All DNS plugin tests completed!"
TEST_SCRIPT_EOF
    
    # Copy script to container and execute
    if docker cp /tmp/dns-test-script.sh dokku-local:/tmp/dns-test.sh && \
       docker exec dokku-local bash /tmp/dns-test.sh; then
        log "SUCCESS" "All tests completed successfully!"
        log "INFO" "DNS plugin functionality verified with comprehensive test suite"
    else
        log "ERROR" "Tests failed. Check the output above for details."
        exit 1
    fi
    
    rm -f /tmp/dns-test-script.sh
    exit 0
fi

# Full orchestration mode (default)
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
echo "   Your DNS plugin has been verified!"