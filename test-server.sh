#!/usr/bin/env bash
set -euo pipefail

# Remote server test script for dokku-dns-sync plugin
# Usage: ./test-server.sh [server-hostname] [ssh-user]

SERVER_HOST="${1:-your-server.com}"
SSH_USER="${2:-root}"
PLUGIN_NAME="dns-sync"
PLUGIN_REPO="https://github.com/deanmarano/dokku-dns-sync.git"
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
    
    if ssh "$SSH_USER@$SERVER_HOST" "$command" 2>&1 | tee -a "$LOG_FILE"; then
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
    if ! ssh -o ConnectTimeout=10 "$SSH_USER@$SERVER_HOST" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        log "ERROR" "Cannot connect to $SERVER_HOST as $SSH_USER"
        log "ERROR" "Please check your SSH configuration and server details"
        exit 1
    fi
    log "SUCCESS" "SSH connection established"
    echo ""
    
    # Check if Dokku is installed
    log "INFO" "Checking if Dokku is installed..."
    run_remote_command "Check Dokku version" "sudo -n dokku version" || {
        log "ERROR" "Dokku is not installed or not working on the server"
        exit 1
    }
    echo ""
    
    # Check current plugin status
    log "INFO" "Checking current plugin status..."
    run_remote_command "List installed plugins" "sudo -n dokku plugin:list"
    echo ""
    
    # Check if dns-sync plugin is installed
    log "INFO" "Checking if dns-sync plugin is currently installed..."
    if run_remote_command "Check dns-sync plugin" "sudo -n dokku plugin:list | grep -q dns-sync"; then
        log "WARNING" "DNS Sync plugin is currently installed, will uninstall first"
        
        # Uninstall existing plugin
        log "INFO" "Uninstalling existing dns-sync plugin..."
        run_remote_command "Uninstall dns-sync plugin" "sudo -n dokku plugin:uninstall dns-sync --force" || {
            log "WARNING" "Plugin uninstall failed, continuing anyway..."
        }
    else
        log "INFO" "DNS Sync plugin is not currently installed"
    fi
    echo ""
    
    # Install the plugin from GitHub
    log "INFO" "Installing dns-sync plugin from GitHub..."
    run_remote_command "Install dns-sync plugin" "sudo -n dokku plugin:install $PLUGIN_REPO" || {
        log "ERROR" "Plugin installation failed"
        exit 1
    }
    echo ""
    
    # Verify installation
    log "INFO" "Verifying installation..."
    run_remote_command "Verify plugin installation" "sudo -n dokku plugin:list | grep dns-sync"
    echo ""
    
    # Check available commands
    log "INFO" "Checking available dns-sync commands..."
    run_remote_command "List dns-sync commands" "sudo -n dokku help | grep dns-sync"
    echo ""
    
    # Test basic command functionality
    log "INFO" "Testing basic command functionality..."
    run_remote_command "Test dns-sync help" "sudo -n dokku dns-sync:help" || {
        log "WARNING" "Help command failed, but plugin might still work"
    }
    echo ""
    
    # Test service configuration (and cleanup)
    log "INFO" "Testing service configuration..."
    SERVICE_NAME="test-service-$(date +%s)"
    
    if run_remote_command "Configure test service" "sudo -n dokku dns-sync:configure $SERVICE_NAME aws"; then
        log "SUCCESS" "Service configuration successful"
        
        # Test backend-auth command (will fail without input, but should show it's working)
        run_remote_command "Test backend-auth command" "timeout 5s sudo -n dokku dns-sync:backend-auth $SERVICE_NAME < /dev/null || true" || {
            log "INFO" "Backend-auth command timed out as expected (requires input)"
        }
        
        # Clean up test service
        run_remote_command "Clean up test service" "sudo -n dokku --force dns-sync:destroy $SERVICE_NAME" || {
            log "WARNING" "Failed to clean up test service $SERVICE_NAME"
        }
    else
        log "ERROR" "Service configuration failed"
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
    log "INFO" "You can now test the plugin with:"
    echo "  ssh $SSH_USER@$SERVER_HOST"
    echo "  sudo dokku dns-sync:configure myservice aws"
    echo "  sudo dokku dns-sync:backend-auth myservice"
    echo "  sudo dokku dns-sync:link myservice myapp"
    echo "  sudo dokku dns-sync:sync myservice"
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi