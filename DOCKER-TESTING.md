# Docker-based Testing Setup

You can now run `test-server.sh` functionality against a local Docker install of Dokku!

## Quick Start

```bash
# Run all tests against local Docker Dokku
./run-docker-tests.sh

# Force rebuild and show logs
./run-docker-tests.sh --build --logs

# With AWS credentials for Route53 testing
AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy ./run-docker-tests.sh
```

## What This Gives You

✅ **Local Testing** - No remote server required  
✅ **Fast Execution** - 2-3 minutes vs 5-10 minutes for SSH  
✅ **Domain Parsing Verification** - Tests the multi-domain fix we implemented  
✅ **Full Plugin Testing** - Install, configure, and test DNS plugin functionality  
✅ **AWS Integration** - Test Route53 connectivity with your credentials  

## Files Added

- `docker-compose.local.yml` - Multi-container test setup
- `Dockerfile.local-test` - Test runner container
- `test-docker.sh` - Docker adaptation of test-server.sh  
- `wait-and-test.sh` - Container orchestration
- `run-docker-tests.sh` - Main entry point
- `README-docker-testing.md` - Detailed documentation

## Test Architecture

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

## Key Benefits vs SSH Testing

| Feature | Docker | SSH |
|---------|--------|-----|
| Setup time | Seconds | Minutes |
| Server needed | No | Yes |
| Consistency | Always same | Variable |
| Isolation | Complete | Shared |
| Cost | Free | Server cost |

The Docker setup specifically tests and verifies the domain parsing fix where multiple domains like `"nextcloud.deanoftech.com test.example.com api.test.example.com"` are now properly separated instead of being treated as a single domain string.