#!/usr/bin/env bash
set -euo pipefail

# Remote server test script for dokku-dns-sync plugin (Single SSH Session)
# Usage: ./test-server.sh [server-hostname] [ssh-user] [test-app]

SERVER_HOST="${1:-your-server.com}"
SSH_USER="${2:-root}"
TEST_APP="${3:-nextcloud}"
PLUGIN_NAME="dns"
PLUGIN_REPO="https://github.com/deanmarano/dokku-dns.git"
LOG_FILE="test-server-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

generate_remote_script() {
    local script_file="/tmp/dokku-dns-test-script.sh"
    
    cat > "$script_file" << 'REMOTE_SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail

# Function to log with timestamps
log_remote() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1: $2"
}

# Check current AWS state
log_remote "INFO" "=== CHECKING CURRENT AWS CONFIGURATION ==="
echo 'Current AWS CLI state:'
if command -v aws >/dev/null 2>&1; then
    echo '✓ AWS CLI is installed'
    if aws sts get-caller-identity 2>/dev/null; then
        echo '✓ AWS CLI is configured and authenticated'
    else
        echo '⚠ AWS CLI is installed but not configured'
    fi
else
    echo '- AWS CLI is not installed'
fi

# Backup existing AWS configuration
log_remote "INFO" "=== BACKING UP EXISTING AWS CONFIGURATION ==="
if [[ -f ~/.aws/credentials ]]; then
    cp ~/.aws/credentials /tmp/aws_credentials_backup
    echo 'Backed up existing AWS credentials'
else
    echo 'No existing AWS credentials to backup'
fi
if [[ -f ~/.aws/config ]]; then
    cp ~/.aws/config /tmp/aws_config_backup
    echo 'Backed up existing AWS config'
else
    echo 'No existing AWS config to backup'
fi

# Check Dokku version
log_remote "INFO" "=== CHECKING DOKKU ==="
sudo dokku version

# List current plugins
log_remote "INFO" "=== CURRENT PLUGIN STATUS ==="
sudo dokku plugin:list

# Check if dns plugin is installed and uninstall if needed
log_remote "INFO" "=== CHECKING DNS PLUGIN ==="
DNS_PLUGIN_CHECK=$(sudo dokku plugin:list 2>/dev/null | grep dns || echo "not-found")
if [[ "$DNS_PLUGIN_CHECK" != "not-found" ]]; then
    echo "DNS plugin is currently installed: $DNS_PLUGIN_CHECK"
    echo "Uninstalling existing DNS plugin..."
    sudo dokku plugin:uninstall dns --force 2>/dev/null || echo "Standard uninstall failed, trying force removal..."
    sleep 2  # Give time for cleanup
    
    # Force removal of plugin directories
    echo "Forcing removal of plugin directories..."
    sudo rm -rf /var/lib/dokku/plugins/available/dns 2>/dev/null || true
    sudo rm -rf /var/lib/dokku/plugins/enabled/dns 2>/dev/null || true
    
    # Verify removal
    DNS_PLUGIN_RECHECK=$(sudo dokku plugin:list 2>/dev/null | grep dns || echo "not-found")
    if [[ "$DNS_PLUGIN_RECHECK" != "not-found" ]]; then
        echo "Warning: DNS plugin still present after cleanup: $DNS_PLUGIN_RECHECK"
    else
        echo "✓ DNS plugin successfully removed"
    fi
else
    echo "DNS plugin is not currently installed"
fi

REMOTE_SCRIPT_EOF

    # Add AWS credential setup if credentials are available
    if [[ -n "${AWS_ACCESS_KEY:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        cat >> "$script_file" << CRED_SCRIPT_EOF

# Set up temporary AWS credentials for testing
log_remote "INFO" "=== SETTING UP TEMPORARY AWS CREDENTIALS ==="
echo "Local AWS credentials detected - configuring temporarily on remote server"
echo "Test app: ${TEST_APP}"

# Configure for current user
mkdir -p ~/.aws
cat > ~/.aws/credentials << 'AWS_CRED_EOF'
[default]
aws_access_key_id = ${AWS_ACCESS_KEY}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
AWS_CRED_EOF

# Also configure for root (for sudo operations like plugin install)
sudo mkdir -p /root/.aws
sudo tee /root/.aws/credentials > /dev/null << 'AWS_CRED_EOF'
[default]
aws_access_key_id = ${AWS_ACCESS_KEY}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
AWS_CRED_EOF

# Configure region for both users
cat > ~/.aws/config << 'AWS_CONFIG_EOF'
[default]
region = us-east-1
output = json
AWS_CONFIG_EOF

sudo tee /root/.aws/config > /dev/null << 'AWS_CONFIG_EOF'
[default]
region = us-east-1
output = json
AWS_CONFIG_EOF

# Test AWS CLI configuration
log_remote "INFO" "Testing AWS CLI configuration..."
aws sts get-caller-identity
echo "✓ Temporary AWS credentials configured - expecting best-case auto-detection!"
CRED_SCRIPT_EOF
    else
        cat >> "$script_file" << 'NO_CRED_SCRIPT_EOF'

log_remote "INFO" "=== NO AWS CREDENTIALS PROVIDED ==="
echo "No local AWS credentials found in environment"
echo "Test app: ${TEST_APP}"
echo "Set AWS_ACCESS_KEY and AWS_SECRET_ACCESS_KEY to test with credentials"
NO_CRED_SCRIPT_EOF
    fi

    # Add the rest of the script
    cat >> "$script_file" << 'REMOTE_SCRIPT_EOF2'

# Install the plugin
log_remote "INFO" "=== INSTALLING DNS PLUGIN ==="
REMOTE_SCRIPT_EOF2

    if [[ -n "${AWS_ACCESS_KEY:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        cat >> "$script_file" << 'WITH_CRED_MSG_EOF'
echo "Expected installation scenario with AWS credentials:"
echo "  🚀 Best case expected: AWS CLI ready with Route53 access → Immediate use"
echo "     Should see: ✓ Route53 access confirmed with hosted zone count"
WITH_CRED_MSG_EOF
    else
        cat >> "$script_file" << 'NO_CRED_MSG_EOF'
echo "Expected installation scenarios without credentials:"
echo "  🔧 Expected: AWS CLI detected → Needs 'aws configure'"
echo "  ⚙️ Fallback: No CLI detected → Manual setup required"
NO_CRED_MSG_EOF
    fi

    cat >> "$script_file" << 'REMOTE_SCRIPT_EOF3'

sudo dokku plugin:install https://github.com/deanmarano/dokku-dns.git

# Verify installation
log_remote "INFO" "=== VERIFYING INSTALLATION ==="
sudo dokku plugin:list | grep dns
sudo dokku help | grep dns
sudo dokku dns:help || echo "Help command failed, but plugin might still work"

# Test provider capabilities
log_remote "INFO" "=== TESTING PROVIDER CAPABILITIES ==="
if command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
    echo "✓ AWS CLI is installed and configured - should be ready to use"
    aws route53 list-hosted-zones >/dev/null 2>&1 && echo 'Route53 access confirmed' || echo 'Route53 access limited'
    sudo dokku dns:verify 2>&1 || true
elif command -v aws >/dev/null 2>&1; then
    echo "🔧 AWS CLI is installed but not configured"
    timeout 10s sudo dokku dns:verify < /dev/null 2>&1 || true
else
    echo "⚙️ AWS CLI not installed"
    sudo dokku dns:verify 2>&1 || true
fi

# Test implemented DNS commands only
log_remote "INFO" "=== TESTING IMPLEMENTED DNS COMMANDS ==="

# Test app availability first
echo "Testing with app: ${TEST_APP}"
if ! sudo dokku apps:list 2>/dev/null | grep -q "${TEST_APP}"; then
    echo "Warning: App '${TEST_APP}' not found. Available apps:"
    sudo dokku apps:list 2>/dev/null || echo "No apps found"
    echo "Using first available app for testing..."
    AVAILABLE_APP=$(sudo dokku apps:list 2>/dev/null | grep -v "====>" | head -1 | xargs)
    if [[ -n "$AVAILABLE_APP" ]]; then
        TEST_APP="$AVAILABLE_APP"
        echo "Using app: $TEST_APP"
    else
        echo "No apps available for testing app-specific commands"
        TEST_APP=""
    fi
fi

# Test the 6 implemented DNS commands
log_remote "INFO" "Testing implemented DNS commands..."

echo "1. Testing dns:help"
sudo dokku dns:help 2>&1 || echo "Help command failed"

echo "2. Testing dns:verify (verify DNS provider setup and connectivity + discover existing records)"
sudo dokku dns:verify 2>&1 || echo "Verify command completed"

echo "3. Testing dns:configure (configure global DNS provider)"
sudo dokku dns:configure 2>&1 || echo "Configure command completed"

if [[ -n "$TEST_APP" ]]; then
    echo "4. Testing dns:add $TEST_APP (add app domains to DNS management)"
    sudo dokku dns:add "$TEST_APP" 2>&1 || echo "Add command completed"
    
    echo "5. Testing dns:sync $TEST_APP (synchronize DNS records for app)"
    sudo dokku dns:sync "$TEST_APP" 2>&1 || echo "Sync command completed"
    
    echo "6. Testing dns:report (global report - all apps and domains)"
    sudo dokku dns:report 2>&1 || echo "Global report command completed"
    
    echo "7. Testing dns:report $TEST_APP (app-specific DNS sync status and domain info)"
    sudo dokku dns:report "$TEST_APP" 2>&1 || echo "App report command completed"
else
    echo "4-5. Skipping app-specific commands (no apps available)"
    echo "     Showing usage for app-required commands:"
    echo "4. Testing dns:add (expects app name)"
    sudo dokku dns:add 2>&1 || echo "Add command shows usage"
    echo "5. Testing dns:sync (expects app name)"  
    sudo dokku dns:sync 2>&1 || echo "Sync command shows usage"
    
    echo "6. Testing dns:report (global report - should work without apps)"
    sudo dokku dns:report 2>&1 || echo "Global report command completed"
    
    echo "7. Testing dns:report with non-existent app (should show usage)"
    sudo dokku dns:report nonexistent-app 2>&1 || echo "App report shows usage"
fi

log_remote "SUCCESS" "DNS command testing completed! Tested 7 implemented command scenarios."

# Test Route53 capabilities if AWS is configured
REMOTE_SCRIPT_EOF3

    if [[ -n "${AWS_ACCESS_KEY:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        cat >> "$script_file" << 'ROUTE53_TEST_EOF'
log_remote "INFO" "=== TESTING ROUTE53 CAPABILITIES ==="
aws route53 list-hosted-zones --query 'HostedZones[].Name' --output table 2>/dev/null || echo 'No hosted zones or limited access'
ROUTE53_TEST_EOF
    fi

    cat >> "$script_file" << 'REMOTE_SCRIPT_EOF4'

log_remote "SUCCESS" "=== PLUGIN TEST COMPLETED ==="

# Cleanup AWS credentials
log_remote "INFO" "=== CLEANING UP AWS CONFIGURATION ==="
if [[ -f /tmp/aws_credentials_backup ]]; then
    mkdir -p ~/.aws
    cp /tmp/aws_credentials_backup ~/.aws/credentials
    echo "Restored original AWS credentials"
else
    rm -f ~/.aws/credentials
    sudo rm -f /root/.aws/credentials
    echo "Removed test AWS credentials"
fi

if [[ -f /tmp/aws_config_backup ]]; then
    mkdir -p ~/.aws
    cp /tmp/aws_config_backup ~/.aws/config
    echo "Restored original AWS config"
else
    rm -f ~/.aws/config
    sudo rm -f /root/.aws/config
    echo "Removed test AWS config"
fi

rm -f /tmp/aws_credentials_backup /tmp/aws_config_backup
echo "✓ AWS configuration restored to original state"

REMOTE_SCRIPT_EOF4

    echo "$script_file"
}

main() {
    log "INFO" "Starting DNS Sync plugin test on server: $SERVER_HOST"
    log "INFO" "SSH User: $SSH_USER"
    log "INFO" "Test App: $TEST_APP"
    log "INFO" "Log file: $LOG_FILE"
    echo ""
    
    # Test SSH connection  
    log "INFO" "Testing SSH connection..."
    if ! ssh -o ConnectTimeout=10 "$SSH_USER@$SERVER_HOST" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        log "ERROR" "Cannot connect to $SERVER_HOST as $SSH_USER"
        log "ERROR" "Please check your SSH configuration and server details"
        exit 1
    fi
    log "SUCCESS" "SSH connection established"
    echo ""
    
    # Generate the remote script
    log "INFO" "Generating remote test script..."
    local SCRIPT_FILE
    SCRIPT_FILE=$(generate_remote_script)
    
    # Check credentials
    if [[ -n "${AWS_ACCESS_KEY:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        log "SUCCESS" "AWS credentials detected - will test best-case auto-detection"
    else
        log "INFO" "No AWS credentials provided - will test basic auto-detection"
        echo "Set AWS_ACCESS_KEY and AWS_SECRET_ACCESS_KEY to test with credentials"
    fi
    echo ""
    
    # Run the entire test in a single SSH session
    log "INFO" "Executing comprehensive test via single SSH session..."
    echo "This will run all tests in one SSH connection to minimize password prompts"
    echo ""
    
    # Copy script and execute
    if scp "$SCRIPT_FILE" "$SSH_USER@$SERVER_HOST:/tmp/dokku-dns-test.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Test script uploaded successfully"
    else
        log "ERROR" "Failed to upload test script"
        exit 1
    fi
    
    # Execute the test script
    if ssh -t "$SSH_USER@$SERVER_HOST" "chmod +x /tmp/dokku-dns-test.sh && /tmp/dokku-dns-test.sh; rm -f /tmp/dokku-dns-test.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "Remote test execution completed"
    else
        log "WARNING" "Remote test completed with some errors"
    fi
    
    # Clean up local script
    rm -f "$SCRIPT_FILE"
    
    echo ""
    echo "===================================================================================="
    log "INFO" "TEST COMPLETED - Log file saved as: $LOG_FILE"
    echo "===================================================================================="
    
    echo ""
    log "INFO" "Manual testing guide:"
    echo "  ssh $SSH_USER@$SERVER_HOST"
    echo ""
    echo "Available commands to test:"
    echo "  sudo dokku dns:help                    # Show all commands"
    echo "  sudo dokku dns:verify                  # Test provider access + discover existing DNS records"
    echo "  sudo dokku dns:configure               # Configure DNS provider"
    echo "  sudo dokku dns:add <app>               # Add app domains to DNS"
    echo "  sudo dokku dns:sync <app>              # Sync DNS records"
    echo "  sudo dokku dns:report                  # Show global report (all apps and domains)"
    echo "  sudo dokku dns:report <app>            # Show app-specific domain status"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi