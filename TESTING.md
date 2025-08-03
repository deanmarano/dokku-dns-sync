# Testing the DNS Plugin

This document explains how to test the DNS plugin with AWS credentials.

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

The test script exercises **all** DNS plugin functions:

1. **`dns:help`** - Command documentation
2. **`dns:configure`** - Provider setup
3. **`dns:verify`** - AWS authentication check
4. **`dns:add`** - Domain registration (shows domain status table!)
5. **`dns:sync`** - DNS record synchronization
6. **`dns:report`** - Status reporting (global and per-app)

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