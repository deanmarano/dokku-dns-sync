# Docker-based Testing for Dokku DNS Plugin

This directory contains Docker-based testing infrastructure that allows you to test the Dokku DNS plugin against a local Docker installation of Dokku, eliminating the need for a remote server.

## Quick Start

1. **Prerequisites**
   - Docker and Docker Compose installed
   - (Optional) AWS credentials for Route53 testing

2. **Run Tests**
   ```bash
   # Basic test run
   ./run-docker-tests.sh
   
   # Force rebuild of images
   ./run-docker-tests.sh --build
   
   # Show container logs after completion
   ./run-docker-tests.sh --logs
   ```

3. **With AWS Credentials** (for Route53 testing)
   ```bash
   # Using environment variables
   AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy ./run-docker-tests.sh
   
   # Or create a .env file
   echo "AWS_ACCESS_KEY_ID=your_key_here" > .env
   echo "AWS_SECRET_ACCESS_KEY=your_secret_here" >> .env
   echo "AWS_DEFAULT_REGION=us-east-1" >> .env
   ./run-docker-tests.sh
   ```

## Files Overview

### Docker Configuration
- **`docker-compose.local.yml`** - Multi-container setup with Dokku and test runner
- **`Dockerfile.local-test`** - Test runner container with all dependencies
- **`Dockerfile.test`** - Lightweight unit test container (existing)

### Test Scripts
- **`run-docker-tests.sh`** - Main entry point for Docker-based testing
- **`test-docker.sh`** - Docker adaptation of the original test-server.sh
- **`wait-and-test.sh`** - Container initialization and orchestration script

## Architecture

The Docker testing setup uses two containers:

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

## Test Flow

1. **Container Startup**
   - Dokku container starts and initializes
   - Test runner waits for Dokku to be ready

2. **Plugin Installation**
   - Copies plugin source from mounted volume
   - Installs DNS plugin via `dokku plugin:install`

3. **Test Execution**
   - Creates test app with multiple domains
   - Tests domain parsing fixes (the main bug we fixed)
   - Verifies DNS provider configuration
   - Runs plugin commands and validates output

4. **Cleanup**
   - Containers are stopped and removed
   - Volumes are cleaned up

## Key Benefits

- **No Remote Server Required**: Test locally without SSH setup
- **Consistent Environment**: Same Dokku version every time
- **Isolated Testing**: No interference with existing systems  
- **Fast Iteration**: Quick rebuilds and test runs
- **Full Integration**: Tests real Dokku plugin installation process

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
./run-docker-tests.sh --build
```

### AWS Credentials
```bash
# Test AWS connectivity
docker exec dokku-local aws sts get-caller-identity
```

## Comparison: Docker vs SSH Testing

| Feature | Docker Testing | SSH Testing (test-server.sh) |
|---------|---------------|-------------------------------|
| Setup | Docker only | SSH keys, remote server |
| Speed | ~2-3 minutes | ~5-10 minutes |
| Isolation | Complete | Shared server state |
| Cost | Free | Server costs |
| Consistency | Same environment | Variable server config |
| Network | Local only | Real internet domains |

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
./run-docker-tests.sh --build
```

This Docker-based testing approach provides a comprehensive, reliable way to validate the DNS plugin functionality without requiring external infrastructure.