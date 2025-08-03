# DNS Plugin Development TODO

## Phase 1: Core Foundation (High Priority) - COMPLETED ✅

- [x] **Update core configuration** - Transform postgres config to dns ✅
- [x] **Create dns:configure** - Initialize global DNS configuration ✅ 
- [x] **Implement dns:set-backend** - Configure AWS/Cloudflare backend ✅
- [x] **Create dns:backend-auth** - Store provider credentials securely ✅
- [x] **Create AWS Route53 backend** - Full aws-cli integration with hosted zone discovery ✅
- [x] **Implement dns:sync** - Manual domain record synchronization ✅
- [x] **Simplify API** - Remove service-based approach, work directly with apps ✅

## Phase 2: Integration (Medium Priority) - COMPLETED ✅

- [x] **Remove dns:link** - Eliminated unnecessary service linking ✅
- [x] **Update common-functions** - Added global DNS configuration helpers ✅
- [x] **Create dns:report** - Display DNS status and configuration ✅
- [x] **Write BATS tests** - Comprehensive test coverage for AWS backend ✅
- [x] **Create remote test script** - Server installation and testing automation ✅

## Phase 3: Polish (In Progress)

- [x] **Clean up help output** - Solidified simplified API design ✅
- [ ] **Add support for multiple DNS record types** - CNAME, MX, TXT records
- [ ] **Implement domain validation** - Validate domains before DNS changes
- [ ] **Add DNS record backup/restore** - Safety features for DNS changes
- [ ] **Create DNS health monitoring** - Periodic DNS record validation
- [ ] **Create Cloudflare backend** - Second provider integration

## Notes

**Major API Simplification**: The plugin has been completely redesigned from a service-based architecture (like dokku-postgres) to a global configuration approach. This eliminates the confusing two-step process and makes DNS work more intuitively with Dokku apps.

### Current API (Consolidated)

```bash
# Core commands
dokku dns:configure [provider]                     # Configure/change DNS provider globally (defaults to aws)
dokku dns:provider-auth                            # Configure provider credentials  
dokku dns:sync <app>                               # Sync all domains for an app to DNS provider
dokku dns:report <app>                             # Show server IP, DNS status with emojis, and hosted zones for an app

# Helper commands
dokku dns:help                                     # Show all available commands
```

### Workflow Example

```bash
# One-time setup
dokku dns:configure aws
dokku dns:provider-auth

# Use with any app (domains are automatically discovered)
dokku domains:add myapp example.com
dokku dns:sync myapp

# Check status
dokku dns:report myapp

# Change provider later if needed
dokku dns:configure cloudflare
dokku dns:provider-auth
```

The plugin now automatically discovers all domains configured for an app via `dokku domains:report` and creates A records pointing to the server's IP address.