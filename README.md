# dokku dns-sync

DNS synchronization plugin for Dokku. Automatically manages DNS records across multiple cloud providers for your Dokku applications.

## Features

- **Multi-backend support**: AWS Route53, Cloudflare (planned)
- **Per-app domain management**: Link DNS services to specific Dokku apps
- **Automatic synchronization**: Updates DNS records when apps are deployed or scaled
- **Secure credential storage**: Encrypted storage of DNS provider credentials
- **Manual sync capability**: Trigger DNS updates on demand

## Requirements

- dokku 0.19.x+
- For AWS Route53: aws-cli installed and configured

## Installation

```shell
sudo dokku plugin:install https://github.com/deanmarano/dokku-dns-sync.git --name dns-sync
```

## Quick Start

```shell
# 1. Configure a DNS sync service
dokku dns-sync:configure prod-dns

# 2. Set the DNS backend (currently supports: aws)
dokku dns-sync:set-backend prod-dns aws

# 3. Configure AWS credentials
dokku dns-sync:backend-auth prod-dns

# 4. Add domains to manage
dokku dns-sync:add-domain prod-dns example.com
dokku dns-sync:add-domain prod-dns api.example.com

# 5. Link to your Dokku app
dokku dns-sync:link prod-dns my-app

# 6. Sync DNS records
dokku dns-sync:sync prod-dns
```

## Commands

### Service Management
```
dns-sync:configure <service>                   # Configure a new DNS sync service
dns-sync:destroy <service>                     # Remove DNS sync service and all configuration
dns-sync:info <service>                        # Show service configuration and status
dns-sync:list                                  # List all DNS sync services
```

### Backend Configuration
```
dns-sync:set-backend <service> <backend>       # Set DNS provider backend (aws, cloudflare)
dns-sync:backend-auth <service>                # Configure DNS provider credentials
```

### Domain Management
```
dns-sync:add-domain <service> <domain>         # Add domain to DNS sync service
dns-sync:remove-domain <service> <domain>     # Remove domain from DNS sync service
```

### App Integration
```
dns-sync:link <service> <app>                  # Link DNS service to Dokku app
dns-sync:unlink <service> <app>                # Unlink DNS service from Dokku app
dns-sync:app-links <app>                       # List DNS services linked to an app
```

### Synchronization
```
dns-sync:sync <service>                        # Manually trigger DNS synchronization
```

## Backends

### AWS Route53

Supports automatic DNS record management via AWS Route53.

**Prerequisites:**
- aws-cli installed
- AWS credentials with Route53 permissions
- Hosted zones configured in Route53 for your domains

**Required IAM permissions:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:ListResourceRecordSets",
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": "*"
        }
    ]
}
```

**Configuration:**
```shell
dokku dns-sync:set-backend myservice aws
dokku dns-sync:backend-auth myservice
# You'll be prompted for: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION
```

### Cloudflare (Planned)

Cloudflare DNS support is planned for a future release.

## Usage Examples

### Basic Setup

Configure DNS sync for a production application:

```shell
# Create DNS service
dokku dns-sync:configure prod-dns

# Configure AWS Route53 backend
dokku dns-sync:set-backend prod-dns aws
dokku dns-sync:backend-auth prod-dns

# Add your domains
dokku dns-sync:add-domain prod-dns myapp.com
dokku dns-sync:add-domain prod-dns www.myapp.com
dokku dns-sync:add-domain prod-dns api.myapp.com

# Link to your app
dokku dns-sync:link prod-dns my-production-app

# Sync DNS (this will create A records pointing to your app's IP)
dokku dns-sync:sync prod-dns
```

### Multiple Environments

Separate DNS services for different environments:

```shell
# Production DNS
dokku dns-sync:configure prod-dns
dokku dns-sync:set-backend prod-dns aws
dokku dns-sync:add-domain prod-dns myapp.com
dokku dns-sync:link prod-dns production-app

# Staging DNS  
dokku dns-sync:configure staging-dns
dokku dns-sync:set-backend staging-dns aws
dokku dns-sync:add-domain staging-dns staging.myapp.com
dokku dns-sync:link staging-dns staging-app
```

## How It Works

1. **Service Configuration**: DNS sync services act as configuration namespaces that group domains with DNS provider credentials
2. **Backend Integration**: Each service uses a specific DNS provider backend (AWS Route53, Cloudflare, etc.)
3. **App Linking**: Services are linked to Dokku apps to determine which IP addresses to sync
4. **Automatic Resolution**: The plugin resolves the current IP address of linked apps
5. **DNS Updates**: A records are created/updated in the DNS provider to point domains to the app's IP

## File Structure

DNS sync services store configuration in `/var/lib/dokku/services/dns-sync/<service>/`:

```
/var/lib/dokku/services/dns-sync/myservice/
├── BACKEND          # DNS provider backend (aws, cloudflare)
├── DOMAINS          # List of domains to manage
├── LINKS            # Linked Dokku apps
├── CONFIG           # Service configuration
└── credentials/     # Encrypted DNS provider credentials
    ├── AWS_ACCESS_KEY_ID
    ├── AWS_SECRET_ACCESS_KEY
    └── AWS_DEFAULT_REGION
```

## Development Status

This plugin is currently in active development. Current status:

**✅ Completed:**
- Core plugin infrastructure
- Service configuration system  
- AWS Route53 backend integration
- Domain management commands
- Manual DNS synchronization

**🚧 In Progress:**
- Additional subcommands (set-backend, backend-auth, add-domain, sync)
- App linking functionality
- Automatic sync hooks

**📋 Planned:**
- Cloudflare backend support
- Automatic sync on app deploy/scale
- Comprehensive test coverage
- Advanced DNS record types (CNAME, MX, etc.)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE.txt file for details.