# DNS Sync Plugin Development TODO

## Phase 1: Core Foundation (High Priority)

- [x] **Update core configuration** - Transform postgres config to dns-sync ✅
- [x] **Create dns-sync:configure** - Initialize DNS service configuration ✅ 
- [ ] **Implement dns-sync:set-backend** - Configure AWS/Cloudflare backend
- [ ] **Create dns-sync:backend-auth** - Store provider credentials securely
- [ ] **Implement dns-sync:add-domain** - Add domains to sync configuration
- [x] **Create AWS Route53 backend** - Basic aws-cli integration ✅
- [ ] **Implement dns-sync:sync** - Manual domain record synchronization

## Phase 2: Integration (Medium Priority)  

- [ ] **Create dns-sync:link** - Associate DNS service with Dokku app
- [ ] **Update common-functions** - Remove postgres utilities, add DNS helpers
- [ ] **Implement dns-sync:info** - Show service configuration and status
- [ ] **Add automatic sync hooks** - Sync on app deploy/scale events

## Phase 3: Polish (Low Priority)

- [ ] **Implement dns-sync:list** - Show all DNS sync services
- [ ] **Create Cloudflare backend** - Second provider integration
- [ ] **Add error handling** - Comprehensive DNS operation validation
- [ ] **Write BATS tests** - Test coverage for all subcommands

## Notes

The first 7 items will get you to a working DNS sync for a single domain with AWS Route53. Items 1-4 establish the foundation, items 5-7 enable actual domain synchronization.

### Expected Command Structure

```bash
dokku dns-sync:configure <service>                 # Configure DNS sync service
dokku dns-sync:destroy <service>                   # Remove DNS sync configuration  
dokku dns-sync:link <service> <app>                # Link DNS service to app
dokku dns-sync:unlink <service> <app>              # Unlink DNS service from app
dokku dns-sync:set <service> <key> <value>         # Set configuration
dokku dns-sync:info <service>                      # Show service information
dokku dns-sync:list                                # List all DNS sync services

# DNS-specific commands
dokku dns-sync:add-domain <service> <domain>       # Add domain to sync
dokku dns-sync:remove-domain <service> <domain>    # Remove domain from sync
dokku dns-sync:sync <service>                      # Manually trigger sync
dokku dns-sync:set-backend <service> <backend>     # Set DNS backend (aws, cloudflare)
dokku dns-sync:backend-auth <service> <credentials> # Configure backend credentials
```