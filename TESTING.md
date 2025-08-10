# Testing the DNS Plugin

This document explains how to test the DNS plugin comprehensively with different testing approaches.

## 🏗️ Testing Architecture

The DNS plugin uses **integration tests** rather than complex unit tests because:
- ✅ DNS functionality is primarily about integration (Dokku + cloud providers)
- ✅ Real behavior matters more than isolated units
- ✅ Simpler, more reliable test architecture
- ✅ Easier to maintain and debug

### Previous Issues with BATS Unit Tests
The original BATS-based unit tests had fundamental architectural problems:
- **Architecture Mismatch**: Tests designed for mock environment but run against real Dokku
- **Path Confusion**: Complex routing between mock dokku vs real dokku commands  
- **State Management**: Real Dokku persists data, BATS assumes clean slate
- **Permission Conflicts**: Filesystem permissions vs test cleanup expectations

## 🧪 Testing Methods

### Method 1: Integration Tests (Recommended)

Use the new integration test script for comprehensive testing:

```bash
# Test against local Dokku installation
./test-integration.sh

# Test against Docker Dokku environment  
docker-compose -f docker-compose.local.yml up -d
docker exec dokku-local bash -c 'cd /tmp/dokku-dns && ./test-integration.sh'
```

**What it tests:**
- ✅ All DNS commands (configure, add, sync, verify, report, remove)
- ✅ Error conditions and edge cases
- ✅ Help system and version information
- ✅ Real Dokku integration behavior
- ✅ Provider switching and configuration
- ✅ App lifecycle management

### Method 2: Remote Server Testing  

For testing against real servers with AWS credentials:

## 🔐 Secure Credential Management

### Option 1: .env File (Recommended)

1. Copy the example file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your AWS credentials:
   ```bash
   # AWS Credentials for DNS Plugin Testing
   AWS_ACCESS_KEY_ID=AKIA...
   AWS_SECRET_ACCESS_KEY=your_secret_key
   AWS_DEFAULT_REGION=us-east-1
   ```

3. Run the test:
   ```bash
   ./test-server.sh your-server.com your-user
   ```

### Option 2: Environment Variables

Set credentials in your shell:
```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_DEFAULT_REGION=us-east-1
./test-server.sh your-server.com your-user
```

### Option 3: AWS Profile

Use existing AWS CLI configuration:
```bash
aws configure  # if not already configured
./test-server.sh your-server.com your-user
```

## 🧪 What Gets Tested

### With AWS Credentials:
- ✅ Full sync functionality (`dns:sync`)
- ✅ Hosted zone detection
- ✅ DNS record creation/updates
- ✅ Domain status table with actual hosted zones
- ✅ Route53 integration

### Without AWS Credentials:
- ✅ Plugin installation
- ✅ Command availability
- ✅ Error handling
- ✅ Usage messages
- ❌ Limited sync testing (auth failures)

## 🔒 Security Notes

- `.env` files are git-ignored automatically
- Credentials are only used temporarily on test server
- Original AWS configuration is backed up and restored
- No credentials are stored permanently on the remote server

## 📋 Test Coverage

### Integration Tests (`./test-integration.sh`)
Tests **all** DNS plugin functions with comprehensive assertions:

1. **Help System**
   - `dns:help` - Main help and command listing
   - `dns:help <command>` - Subcommand help
   - `dns:version` - Version information

2. **Configuration Management**
   - `dns:configure aws` - AWS provider setup
   - `dns:configure cloudflare` - Provider switching
   - `dns:configure invalid` - Error handling

3. **Provider Verification**
   - `dns:verify` - AWS CLI status checking
   - Error states with no provider configured

4. **App Lifecycle Management**
   - `dns:add <app>` - Add app to DNS management
   - `dns:sync <app>` - Synchronize DNS records
   - `dns:report` - Global and app-specific reporting
   - `dns:remove <app>` - Remove app from DNS

5. **Error Conditions**
   - Nonexistent apps
   - Missing arguments
   - Invalid providers

### Remote Server Tests (`./test-server.sh`)
Tests with real AWS credentials and hosted zones:

## 🎯 Which Test Method To Use

### Use Integration Tests (`./test-integration.sh`) when:
- ✅ **Development**: Testing plugin functionality during development
- ✅ **CI/CD**: Automated testing without AWS credentials
- ✅ **Quick validation**: Verifying commands work correctly
- ✅ **Regression testing**: Ensuring changes don't break core functionality

### Use Remote Server Tests (`./test-server.sh`) when:
- ✅ **Full validation**: Testing complete AWS Route53 integration
- ✅ **Release testing**: Final validation before releases
- ✅ **Hosted zone testing**: Verifying DNS records are actually created
- ✅ **Performance testing**: Testing against real AWS API

### Legacy BATS Tests (deprecated)
The `./test-bats.sh` Docker tests have architectural issues and should be avoided:
- ❌ Complex mock/real environment conflicts
- ❌ Unreliable setup/teardown in Docker
- ❌ Permission and caching issues
- ❌ Difficult to maintain and debug

**Recommendation**: Use integration tests for development, remote server tests for full validation.

## 🎯 Expected Results

### With Valid AWS Credentials:
```
4. Testing dns:add nextcloud (add app domains to DNS management)
   This should show the new domain status table with hosted zones!
=====> Domain Status Table for app 'nextcloud':
=====> Domain                         Status   Enabled         Provider        Hosted Zone
=====> ------                         ------   -------         --------        -----------
nextcloud.example.com                 ❌      Yes             aws             example.com
test.example.com                      ❌      Yes             aws             example.com

5. Testing dns:sync nextcloud (synchronize DNS records for app)
=====> Syncing DNS records for app 'nextcloud'
-----> Updated DNS record: nextcloud.example.com -> 192.168.1.100
-----> Updated DNS record: test.example.com -> 192.168.1.100
=====> DNS sync completed successfully
```

### Without AWS Credentials:
```
5. Testing dns:sync nextcloud (synchronize DNS records for app)
 !     AWS CLI is not configured or credentials are invalid.
    
Run: dokku dns:verify
```