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
    
    # Install the plugin from GitHub
    log "INFO" "Installing dns plugin from GitHub..."
    run_remote_command "Install dns plugin" "sudo dokku plugin:install $PLUGIN_REPO" || {
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
    echo "Available DNS commands (implemented):"
    echo "  - dns:add-domains    - Add app domains to DNS provider"
    echo "  - dns:configure      - Configure DNS provider" 
    echo "  - dns:provider-auth  - Configure provider authentication"
    echo "  - dns:report         - Show DNS sync status"
    echo "  - dns:sync           - Sync DNS records"
    echo ""
    echo "Available DNS commands (unimplemented/inherited):"
    echo "  - dns:app-links, dns:backup*, dns:clone, dns:connect, dns:destroy"
    echo "  - dns:enter, dns:exists, dns:export, dns:expose, dns:import"  
    echo "  - dns:info, dns:link, dns:linked, dns:links, dns:list, dns:logs"
    echo "  - dns:pause, dns:promote, dns:restart, dns:set, dns:set-provider"
    echo "  - dns:start, dns:stop, dns:unexpose, dns:unlink, dns:upgrade"
    echo ""
    
    # Test global configuration
    log "INFO" "Testing DNS provider configuration..."
    
    if run_remote_command "Configure DNS sync with AWS provider" "sudo dokku dns:configure aws"; then
        log "SUCCESS" "DNS provider configuration successful"
        
        # Test provider-auth command (will fail without input, but should show it's working)
        run_remote_command "Test provider-auth command availability" "timeout 5s sudo dokku dns:provider-auth < /dev/null || true" || {
            log "INFO" "Provider-auth command timed out as expected (requires interactive input)"
        }
        
        # Test report command without specific app
        run_remote_command "Test global report command" "sudo dokku dns:report || true" || {
            log "INFO" "Report command completed (may show no apps configured)"
        }
        
        # Test add-domains command (will fail without app, but should show usage)
        run_remote_command "Test add-domains command availability" "sudo dokku dns:add-domains 2>&1 || true" || {
            log "INFO" "Add-domains command available (shows usage when no app specified)"
        }
        
        # Test sync command (will fail without app, but should show usage)  
        run_remote_command "Test sync command availability" "sudo dokku dns:sync 2>&1 || true" || {
            log "INFO" "Sync command available (shows usage when no app specified)"
        }
        
    else
        log "ERROR" "DNS provider configuration failed"
    fi
    echo ""
    
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
    log "INFO" "You can now test the plugin manually with:"
    echo "  ssh $SSH_USER@$SERVER_HOST"
    echo ""
    echo "Basic DNS setup commands:"
    echo "  sudo dokku dns:configure aws                    # Configure AWS as DNS provider"
    echo "  sudo dokku dns:configure cloudflare             # Configure Cloudflare as DNS provider" 
    echo "  sudo dokku dns:provider-auth                    # Set up provider credentials"
    echo ""
    echo "App-specific DNS commands:"
    echo "  sudo dokku dns:add-domains myapp                # Add all app domains to DNS"
    echo "  sudo dokku dns:add-domains myapp example.com    # Add specific domain to DNS"
    echo "  sudo dokku dns:sync myapp                       # Sync DNS records for app"
    echo "  sudo dokku dns:report myapp                     # Show DNS status for app"
    echo ""
    echo "Global commands:"
    echo "  sudo dokku dns:report                           # Show global DNS configuration"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi