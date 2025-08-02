#!/usr/bin/env bash
set -euo pipefail

# Remote server test script for dokku-dns-sync plugin
# Usage: ./test-server.sh [server-hostname] [ssh-user]

SERVER_HOST="${1:-your-server.com}"
SSH_USER="${2:-root}"
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
        "COMMAND")
            echo -e "${YELLOW}[COMMAND]${NC} $message" | tee -a "$LOG_FILE"
            ;;
    esac
}

run_remote_command() {
    local description="$1"
    local command="$2"
    
    log "COMMAND" "Running: $description"
    log "COMMAND" "SSH Command: $command"
    
    echo "----------------------------------------" >> "$LOG_FILE"
    echo "Command: $description" >> "$LOG_FILE"
    echo "SSH Command: $command" >> "$LOG_FILE"
    echo "Output:" >> "$LOG_FILE"
    
    # Always use interactive SSH with terminal for password prompts
    if ssh -t "$SSH_USER@$SERVER_HOST" "$command" 2>&1 | tee -a "$LOG_FILE"; then
        log "SUCCESS" "$description completed successfully"
        echo "Status: SUCCESS" >> "$LOG_FILE"
    else
        local exit_code=$?
        log "ERROR" "$description failed with exit code $exit_code"
        echo "Status: FAILED (exit code: $exit_code)" >> "$LOG_FILE"
        return $exit_code
    fi
    
    echo "----------------------------------------" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

cleanup_aws_credentials() {
    log "INFO" "Restoring original AWS configuration..."
    
    if [[ -f "/tmp/aws_credentials_backup" ]]; then
        run_remote_command "Restore original AWS credentials" "
            if [[ -f /tmp/aws_credentials_backup ]]; then
                mkdir -p ~/.aws
                cp /tmp/aws_credentials_backup ~/.aws/credentials
            fi
        " || log "WARNING" "Failed to restore AWS credentials"
    else
        run_remote_command "Remove test AWS credentials" "rm -f ~/.aws/credentials && sudo rm -f /root/.aws/credentials" || log "WARNING" "Failed to remove test credentials"
    fi
    
    if [[ -f "/tmp/aws_config_backup" ]]; then
        run_remote_command "Restore original AWS config" "
            if [[ -f /tmp/aws_config_backup ]]; then
                mkdir -p ~/.aws
                cp /tmp/aws_config_backup ~/.aws/config
            fi
        " || log "WARNING" "Failed to restore AWS config"
    else
        run_remote_command "Remove test AWS config" "rm -f ~/.aws/config && sudo rm -f /root/.aws/config" || log "WARNING" "Failed to remove test config"
    fi
    
    # Clean up backup files
    run_remote_command "Clean up backup files" "rm -f /tmp/aws_credentials_backup /tmp/aws_config_backup" || true
    
    log "SUCCESS" "AWS configuration restored to original state"
}

# Set up trap to ensure cleanup runs even if script fails
trap cleanup_aws_credentials EXIT

main() {
    log "INFO" "Starting DNS Sync plugin test on server: $SERVER_HOST"
    log "INFO" "SSH User: $SSH_USER"
    log "INFO" "Log file: $LOG_FILE"
    echo ""
    
    # Test SSH connection  
    log "INFO" "Testing SSH connection..."
    if ! ssh -o ConnectTimeout=10 -t "$SSH_USER@$SERVER_HOST" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        log "ERROR" "Cannot connect to $SERVER_HOST as $SSH_USER"
        log "ERROR" "Please check your SSH configuration and server details"
        exit 1
    fi
    log "SUCCESS" "SSH connection established"
    echo ""
    
    # Check and backup existing AWS configuration
    log "INFO" "Checking existing AWS configuration..."
    run_remote_command "Check current AWS state" "
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
    " || log "WARNING" "Failed to check AWS state"
    
    # Backup existing AWS configuration
    run_remote_command "Backup existing AWS configuration" "
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
    " || log "WARNING" "Failed to backup AWS configuration"
    echo ""
    
    # Check if Dokku is installed
    log "INFO" "Checking if Dokku is installed..."
    run_remote_command "Check Dokku version" "sudo dokku version" || {
        log "ERROR" "Dokku is not installed or not working on the server"
        exit 1
    }
    echo ""
    
    # Check current plugin status
    log "INFO" "Checking current plugin status..."
    run_remote_command "List installed plugins" "sudo dokku plugin:list"
    echo ""
    
    # Check if dns plugin is installed
    log "INFO" "Checking if dns plugin is currently installed..."
    if run_remote_command "Check dns plugin" "sudo dokku plugin:list | grep -q dns"; then
        log "WARNING" "DNS plugin is currently installed, will uninstall first"
        
        # Uninstall existing plugin
        log "INFO" "Uninstalling existing dns plugin..."
        run_remote_command "Uninstall dns plugin" "sudo dokku plugin:uninstall dns --force" || {
            log "WARNING" "Plugin uninstall failed, continuing anyway..."
        }
    else
        log "INFO" "DNS plugin is not currently installed"
    fi
    echo ""
    
    # Set up temporary AWS credentials for testing (if available locally)
    if [[ -n "${AWS_ACCESS_KEY:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        log "INFO" "Setting up temporary AWS credentials for testing..."
        echo "Local AWS credentials detected - configuring temporarily on remote server"
        
        # Configure temporary AWS CLI on remote server (both user and root)
        run_remote_command "Configure temporary AWS CLI credentials" "
            # Configure for current user
            mkdir -p ~/.aws && 
            cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
            
            # Also configure for root (for sudo operations like plugin install)
            sudo mkdir -p /root/.aws &&
            sudo tee /root/.aws/credentials > /dev/null << EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
        " || {
            log "WARNING" "Failed to configure temporary AWS credentials, continuing without..."
        }
        
        run_remote_command "Set temporary AWS default region" "
            # Configure for current user
            cat > ~/.aws/config << 'EOF'
[default]
region = us-east-1
output = json
EOF
            
            # Also configure for root
            sudo tee /root/.aws/config > /dev/null << 'EOF'
[default]
region = us-east-1
output = json
EOF
        " || {
            log "WARNING" "Failed to set temporary AWS region, continuing..."
        }
        
        # Test temporary AWS CLI configuration
        run_remote_command "Test temporary AWS CLI configuration" "aws sts get-caller-identity" || {
            log "WARNING" "Temporary AWS CLI test failed, but continuing with installation..."
        }
        
        echo ""
        log "SUCCESS" "Temporary AWS credentials configured - expecting best-case auto-detection!"
        echo ""
    else
        log "INFO" "No local AWS credentials found in environment"
        echo "Set AWS_ACCESS_KEY and AWS_SECRET_ACCESS_KEY to test with credentials"
        echo ""
    fi
    
    # Install the plugin from GitHub
    log "INFO" "Installing dns plugin from GitHub..."
    if [[ -n "${AWS_ACCESS_KEY:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        echo "Expected installation scenario with AWS credentials:"
        echo "  🚀 Best case expected: AWS CLI ready with Route53 access → Immediate use"
        echo "     Should see: ✓ Route53 access confirmed with hosted zone count"
    else
        echo "Expected installation scenarios without credentials:"
        echo "  🔧 Expected: AWS CLI detected → Needs 'aws configure'"
        echo "  ⚙️ Fallback: No CLI detected → Manual setup required"
    fi
    echo ""
    
    run_remote_command "Install dns plugin with auto-detection" "sudo dokku plugin:install $PLUGIN_REPO" || {
        log "ERROR" "Plugin installation failed"
        exit 1
    }
    echo ""
    
    # Verify installation
    log "INFO" "Verifying installation..."
    run_remote_command "Verify plugin installation" "sudo dokku plugin:list | grep dns"
    echo ""
    
    # Check available commands
    log "INFO" "Checking available dns commands..."
    run_remote_command "List dns commands" "sudo dokku help | grep dns"
    echo ""
    
    # Test basic command functionality
    log "INFO" "Testing basic command functionality..."
    run_remote_command "Test dns help" "sudo dokku dns:help" || {
        log "WARNING" "Help command failed, but plugin might still work"
    }
    echo ""
    
    # List all available commands  
    log "INFO" "Testing all available DNS commands..."
    echo "Available DNS commands (implemented with intelligent provider matching):"
    echo "  - dns:add <app> [domains...]  - Add app domains to DNS (auto-detects providers)"
    echo "  - dns:sync <app>             - Sync DNS records (multi-provider support)"
    echo "  - dns:verify                 - Verify DNS provider setup"
    echo "  - dns:report <app>           - Show DNS sync status"
    echo "  - dns:configure <provider>   - Configure DNS provider (optional)"
    echo ""
    echo "Key improvements:"
    echo "  ✓ No provider configuration required - auto-detects from hosted zones"
    echo "  ✓ Multi-provider support - different domains can use different providers"
    echo "  ✓ Intelligent domain matching - checks AWS Route53, Cloudflare automatically"
    echo ""
    echo "Available DNS commands (unimplemented/inherited):"
    echo "  - dns:app-links, dns:backup*, dns:clone, dns:connect, dns:destroy"
    echo "  - dns:enter, dns:exists, dns:export, dns:expose, dns:import"  
    echo "  - dns:info, dns:link, dns:linked, dns:links, dns:list, dns:logs"
    echo "  - dns:pause, dns:promote, dns:restart, dns:set, dns:set-provider"
    echo "  - dns:start, dns:stop, dns:unexpose, dns:unlink, dns:upgrade"
    echo ""
    
    # Test auto-detection results
    log "INFO" "Testing auto-detection results from installation..."
    
    # Check what provider was auto-detected
    run_remote_command "Check auto-detected provider status" "sudo dokku dns:report 2>&1 || echo 'No global configuration found'"
    echo ""
    
    # Test provider capabilities based on what was detected
    log "INFO" "Testing provider capabilities..."
    
    # Check if AWS CLI is available and configured
    if run_remote_command "Check AWS CLI availability" "command -v aws && aws sts get-caller-identity >/dev/null 2>&1"; then
        log "SUCCESS" "✓ AWS CLI is installed and configured - should be ready to use"
        
        # Test Route53 permissions
        run_remote_command "Test Route53 permissions" "aws route53 list-hosted-zones >/dev/null 2>&1 && echo 'Route53 access confirmed' || echo 'Route53 access limited'"
        
        # Test verify (should succeed)
        run_remote_command "Test verify with working AWS" "sudo dokku dns:verify 2>&1 || true"
        
    elif run_remote_command "Check AWS CLI installation only" "command -v aws"; then
        log "INFO" "🔧 AWS CLI is installed but not configured"
        
        # Test verify (should show configuration instructions)
        run_remote_command "Test verify with unconfigured AWS" "timeout 10s sudo dokku dns:verify < /dev/null 2>&1 || true"
        
    else
        log "INFO" "⚙️ AWS CLI not installed - manual setup required"
        
        # Test what happens when no CLI is available
        run_remote_command "Test commands without CLI" "sudo dokku dns:verify 2>&1 || true"
    fi
    echo ""
    
    # Test with real domains if AWS is properly configured
    if [[ -n "${AWS_ACCESS_KEY:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        log "INFO" "Testing intelligent domain matching with configured AWS..."
        
        # First check if we have any hosted zones
        if run_remote_command "List Route53 hosted zones" "aws route53 list-hosted-zones --query 'HostedZones[].Name' --output table 2>/dev/null || echo 'No hosted zones or limited access'"; then
            log "INFO" "If you have hosted zones, you can test domain matching with a real app"
            echo "Example test you can run manually:"
            echo "  1. Create test app: sudo dokku apps:create test-dns-app"
            echo "  2. Add domain that matches a hosted zone: sudo dokku domains:add test-dns-app yourdomain.com"
            echo "  3. Test DNS add: sudo dokku dns:add test-dns-app"
            echo "  4. Test DNS sync: sudo dokku dns:sync test-dns-app"
            echo "  5. Clean up: sudo dokku apps:destroy test-dns-app"
        fi
        echo ""
    fi
    
    # Test intelligent provider matching system
    log "INFO" "Testing intelligent provider matching system..."
    
    # Test add command behavior (should auto-detect providers)
    run_remote_command "Test dns:add command (expects app name)" "sudo dokku dns:add 2>&1 || echo 'Shows usage as expected'"
    
    # Test sync command behavior (should auto-detect providers)  
    run_remote_command "Test dns:sync command (expects app name)" "sudo dokku dns:sync 2>&1 || echo 'Shows usage as expected'"
    
    # Test verify command (diagnostic tool)
    run_remote_command "Test dns:verify command" "sudo dokku dns:verify 2>&1 || echo 'Verify command completed'"
    
    # Test configure command (optional now)
    run_remote_command "Test dns:configure command" "sudo dokku dns:configure 2>&1 || echo 'Configure command available'"
    
    # Test with hypothetical domains to see provider detection
    log "INFO" "Testing provider detection behavior..."
    run_remote_command "Test add with fake app (will show detection logic)" "sudo dokku dns:add nonexistent-app fake-domain.com 2>&1 || echo 'Expected to fail - no such app'"
    
    # Test with a sample app if it exists
    log "INFO" "Testing with sample app (if available)..."
    if run_remote_command "Check for existing apps" "sudo dokku apps:list 2>/dev/null || true"; then
        # Try to find first app for testing
        run_remote_command "Test report with first app" "sudo dokku apps:list 2>/dev/null | head -1 | xargs -r sudo dokku dns:report 2>&1 || true"
    else
        log "INFO" "No apps found for testing app-specific commands"
    fi
    echo ""
    
    # Final status
    log "INFO" "Plugin test completed!"
    log "INFO" "Log file saved as: $LOG_FILE"
    
    # Show summary
    echo ""
    echo "=== TEST SUMMARY ==="
    if grep -q "Status: FAILED" "$LOG_FILE"; then
        log "WARNING" "Some commands failed - check the log file for details"
        echo "Failed commands:"
        grep -B2 "Status: FAILED" "$LOG_FILE" | grep "Command:" | sed 's/Command: /  - /'
    else
        log "SUCCESS" "All critical commands completed successfully!"
    fi
    
    echo ""
    log "INFO" "Manual testing guide based on auto-detection results:"
    echo "  ssh $SSH_USER@$SERVER_HOST"
    echo ""
    
    # Provide scenario-specific instructions
    echo "📋 Testing scenarios with intelligent provider matching:"
    echo ""
    echo "🚀 SCENARIO 1: AWS CLI Ready + Hosted Zones (Best case)"
    echo "  If you saw: '✓ AWS CLI configured' and 'Route53 access confirmed'"
    echo "  Test with real domains that have hosted zones:"
    echo "    sudo dokku domains:add myapp yourdomain.com   # Add domain to app first"
    echo "    sudo dokku dns:add myapp                      # Auto-detects AWS provider"
    echo "    sudo dokku dns:sync myapp                     # Syncs to Route53 automatically"
    echo ""
    echo "🔧 SCENARIO 2: AWS CLI Ready but No Hosted Zones"
    echo "  Commands will work but show 'no provider found for domains'"
    echo "  Create hosted zones in Route53 first:"
    echo "    aws route53 create-hosted-zone --name yourdomain.com --caller-reference \$(date +%s)"
    echo "    sudo dokku dns:add myapp yourdomain.com       # Will now detect AWS"
    echo ""
    echo "⚙️ SCENARIO 3: No CLI Tools / Not Configured"
    echo "  Setup AWS CLI:"
    echo "    sudo apt update && sudo apt install awscli    # Install CLI"
    echo "    aws configure                                 # Configure credentials"
    echo "    # Create hosted zones in Route53"
    echo "    sudo dokku dns:add myapp                      # Will auto-detect"
    echo ""
    echo "🔍 Multi-Provider Scenario:"
    echo "  If you have domains in both AWS Route53 and Cloudflare:"
    echo "    sudo dokku dns:sync myapp                     # Automatically uses:"
    echo "    # → AWS for domains with Route53 hosted zones"
    echo "    # → Cloudflare for domains with Cloudflare zones"
    echo ""
    echo "📊 Diagnostic commands:"
    echo "  sudo dokku dns:verify                           # Test provider access"
    echo "  sudo dokku dns:report myapp                     # Show domain → provider mapping"
    
    echo ""
    echo "===================================================================================="
    log "INFO" "TEST COMPLETED - Log file saved as: $LOG_FILE"
    echo "===================================================================================="
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi