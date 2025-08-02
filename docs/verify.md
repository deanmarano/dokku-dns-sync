## AWS Setup

For AWS Route53, you need to configure the AWS CLI on your Dokku server. The DNS plugin will use your existing AWS CLI configuration instead of storing credentials.

**Prerequisites:**
1. Install AWS CLI on your Dokku server
2. Configure AWS credentials with proper Route53 permissions

### Install AWS CLI

```shell
# Ubuntu/Debian
sudo apt update && sudo apt install awscli

# Amazon Linux/CentOS
sudo yum install awscli

# Or install latest version via pip
pip install awscli
```

### Configure AWS Credentials

Choose one of these methods:

#### Option 1: Interactive Configuration (Recommended)
```shell
aws configure
```
This will prompt you for:
- AWS Access Key ID
- AWS Secret Access Key  
- Default region (e.g., us-east-1)
- Output format (json is recommended)

#### Option 2: Environment Variables
```shell
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

#### Option 3: IAM Roles (EC2 only)
If your Dokku server runs on EC2, you can attach an IAM role with Route53 permissions instead of using access keys.

### Required AWS Permissions

Your AWS credentials need these Route53 permissions:

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

You can either:
- Attach the AWS managed policy **AmazonRoute53FullAccess**
- Or create a custom policy with the permissions above

### Verify Setup

After configuring AWS CLI, run:

```shell
dokku dns:verify
```

This will:
- Check if AWS CLI is installed and configured
- Verify your credentials work
- Test Route53 permissions
- List your hosted zones

## Cloudflare Setup

For Cloudflare, the plugin will prompt you for an API token during `dokku dns:verify`.

### Create Cloudflare API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click **Create Token**
3. Use the **Custom token** template
4. Configure:
   - **Permissions**: Zone - Zone:Read, Zone - DNS:Edit
   - **Zone Resources**: Include - All zones (or specific zones)
5. Click **Continue to summary** and **Create Token**
6. Copy the token (you won't see it again)

### Configure Token

Run the verify command and enter your token when prompted:

```shell
dokku dns:verify
```