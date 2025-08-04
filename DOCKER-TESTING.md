# Docker-based Testing for Dokku DNS Plugin

This directory contains Docker-based testing infrastructure that allows you to test the Dokku DNS plugin against a local Docker installation of Dokku, eliminating the need for a remote server.

## Quick Start

### Prerequisites
- Docker and Docker Compose installed
- (Optional) AWS credentials for Route53 testing

### Basic Usage
```bash
# Run all tests against local Docker Dokku
./test-docker.sh

# Force rebuild and show logs
./test-docker.sh --build --logs

# With AWS credentials for Route53 testing
AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy ./test-docker.sh

# Or create a .env file
echo "AWS_ACCESS_KEY_ID=your_key_here" > .env
echo "AWS_SECRET_ACCESS_KEY=your_secret_here" >> .env
echo "AWS_DEFAULT_REGION=us-east-1" >> .env
./test-docker.sh
```

## What This Gives You

✅ **Local Testing** - No remote server required  
✅ **Fast Execution** - 2-3 minutes vs 5-10 minutes for SSH  
✅ **Domain Parsing Verification** - Tests the multi-domain fix we implemented  
✅ **Full Plugin Testing** - Install, configure, and test DNS plugin functionality  
✅ **AWS Integration** - Test Route53 connectivity with your credentials  
✅ **Consistent Environment** - Same Dokku version every time  
✅ **Complete Isolation** - No interference with existing systems  

## Architecture

The Docker testing setup uses two containers:

```
┌─────────────────┐    Docker exec    ┌─────────────────┐
│   Test Runner   │ ──────────────────▶│ Dokku Container │
│   (Ubuntu)      │                    │ (Official Dokku)│
│                 │                    │                 │
│ • BATS tests    │                    │ • Full Dokku    │
│ • AWS CLI       │                    │ • Plugin system │
│ • shellcheck    │                    │ • Apps & domains│
└─────────────────┘                    └─────────────────┘
```

### Container Details

1. **Dokku Container** (`dokku/dokku:0.34.6`)
   - Full Dokku installation
   - Exposes ports 80, 443, and 2222 (SSH)
   - Mounts Docker socket for app deployment
   - Hostname: `dokku-local`

2. **Test Runner Container** (Ubuntu 22.04 based)
   - Contains all testing tools (BATS, shellcheck, AWS CLI)
   - Connects to Dokku container to run tests
   - Executes the DNS plugin test suite

### Container Communication

The test runner communicates with the Dokku container via:
- **Docker exec**: Direct command execution in Dokku container
- **Docker networking**: Internal `dokku-net` bridge network
- **Shared volumes**: Plugin source code mounted read-only

## Files Overview

### Docker Configuration
- **`docker-compose.local.yml`** - Multi-container setup with Dokku and test runner
- **`Dockerfile.local-test`** - Test runner container with all dependencies
- **`Dockerfile.test`** - Lightweight unit test container (existing)

### Test Scripts
- **`run-docker-tests.sh`** - Main entry point for Docker-based testing
- **`test-docker.sh`** - Docker orchestration and comprehensive test execution
- **`wait-and-test.sh`** - Container initialization and orchestration script

## Unified Testing Approach

✅ **No Code Duplication** - Docker tests reuse all logic from `test-server.sh`  
✅ **Single Source of Truth** - Test scenarios maintained in one place  
✅ **Consistent Results** - Docker and SSH testing run identical test suites

## Test Flow

1. **Container Startup**
   - Dokku container starts and initializes
   - Test runner waits for Dokku to be ready

2. **Plugin Installation**
   - Copies plugin source from mounted volume
   - Installs DNS plugin via `dokku plugin:install`

3. **Comprehensive Test Execution**
   - Executes the same comprehensive test suite as remote testing
   - Tests all commands, fixes, and edge cases
   - Verifies domain parsing improvements
   - Tests DNS tracking functionality

4. **Cleanup**
   - Containers are stopped and removed
   - Volumes are cleaned up

## Domain Parsing Verification

The Docker tests specifically verify all the implemented fixes:

### Domain Parsing Fix
1. Adding multiple space-separated domains to a test app:
   - `nextcloud.deanoftech.com`
   - `test.example.com` 
   - `api.test.example.com`

2. Running `dokku dns:add` and `dokku dns:report` commands

3. Verifying that each domain appears as a separate row in the output table (not concatenated)

### DNS Management Tracking 
1. Testing reports for apps before and after adding to DNS management
2. Verifying LINKS file functionality for tracking managed apps
3. Testing global reports only show DNS-managed apps

### Hosted Zone Validation
1. Checking domain status shows proper enabled/disabled based on hosted zone availability
2. Verifying domains without hosted zones show "No (no hosted zone)" status
3. Testing AWS Route53 integration for zone detection

### Plugin Installation Fixes
1. Ensuring no `plugin:install` suggestions appear (already installed)
2. Verifying helpful configuration messages instead

## Key Benefits vs SSH Testing

| Feature | Docker | SSH |
|---------|--------|-----|
| Setup time | Seconds | Minutes |
| Server needed | No | Yes |
| Consistency | Always same | Variable |
| Isolation | Complete | Shared |
| Cost | Free | Server cost |
| Network | Local only | Real internet domains |

## Troubleshooting

### Container Won't Start
```bash
# Check Docker status
docker info

# View container logs
docker-compose -f docker-compose.local.yml logs
```

### Plugin Installation Fails
```bash
# Check Dokku container directly
docker exec -it dokku-local bash
dokku plugin:list
```

### Tests Hang
```bash
# Force cleanup and restart
docker-compose -f docker-compose.local.yml down -v
./test-docker.sh --build
```

### AWS Credentials
```bash
# Test AWS connectivity
docker exec dokku-local aws sts get-caller-identity
```

## Advanced Usage

### Manual Container Interaction
```bash
# Start containers in background
docker-compose -f docker-compose.local.yml up -d

# Connect to Dokku container
docker exec -it dokku-local bash

# Connect to test runner
docker exec -it dokku-dns-test-runner-1 bash

# Run specific commands
docker exec dokku-local dokku dns:help
```

### Custom Test Scenarios
```bash
# Edit test-docker.sh to add custom test cases
# Then rebuild and run
./test-docker.sh --build
```

This Docker-based testing approach provides a comprehensive, reliable way to validate the DNS plugin functionality without requiring external infrastructure. The Docker setup specifically tests and verifies the domain parsing fix where multiple domains like `"nextcloud.deanoftech.com test.example.com api.test.example.com"` are now properly separated instead of being treated as a single domain string.