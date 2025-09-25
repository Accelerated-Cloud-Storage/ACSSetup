### S3 Setup (AWS CLI)

These setup guides demonstrate S3-compatible operations using the AWS CLI. They showcase essential S3 operations including bucket management, object CRUD operations, copying, and multipart uploads with proper configuration, error handling, and resource cleanup.

### Prerequisites

- AWS CLI v2 (recommended) or v1
- Network access to your S3 endpoint
- bash shell

### 1) Install required tools

These setup guides require `aws` (CLI), `jq`, and `openssl`.
If you don't have them installed:

```bash
# For Amazon Linux 2023 / RHEL / CentOS
sudo yum install -y awscli jq openssl

# Or install AWS CLI v2 (recommended)
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 2) Configure your environment for an S3-compatible endpoint

To use these setup guides with your S3-compatible object store, set the following standard AWS variables and one ACS-specific variable for the endpoint:

```bash
# Required: S3-compatible endpoint URL and region
export S3_ENDPOINT="https://acceleratedprod.com"   # ACS endpoint 
export AWS_REGION="global"                         

# Required: S3-compatible credentials (standard AWS env vars)
export AWS_ACCESS_KEY_ID="<YOUR_ACCESS_KEY_ID>"
export AWS_SECRET_ACCESS_KEY="<YOUR_SECRET_ACCESS_KEY>"

export S3_ADDRESSING_STYLE="virtual"  # Note: this env var alone does NOT change AWS CLI behavior unless applied via configure.sh or written to ~/.aws/config (e.g., `aws configure set s3.addressing_style virtual`)
```

You can configure the AWS CLI to work with ACS in several ways:

#### Option A: Using AWS CLI configure command

Configure your default AWS CLI profile for ACS:

```bash
aws configure
```

When prompted, enter:
- **AWS Access Key ID**: Your ACS access key
- **AWS Secret Access Key**: Your ACS secret key  
- **Default region name**: `global`
- **Default output format**: `json`

Then configure S3-specific settings:

```bash
aws configure set s3.addressing_style virtual
```

#### Option B: Manual credentials file setup

Create or edit `~/.aws/credentials`:

```ini
[default]
aws_access_key_id = YourActualAccessKey
aws_secret_access_key = YourActualSecretKey
```

Create or edit `~/.aws/config`:

```ini
[default]
region = global
s3 =
    addressing_style = virtual
```

#### Option C: Using the configuration helper (creates custom profile)

Set your credentials and run the helper script:

```bash
export AWS_ACCESS_KEY_ID="YourActualAccessKey"
export AWS_SECRET_ACCESS_KEY="YourActualSecretKey"

source ./configure.sh
```

**Note**: This option creates a custom `acs-setup` profile without affecting your default AWS configuration.

### How client initialization works in these setup guides

- The scripts pass your endpoint explicitly with `--endpoint-url "$S3_ENDPOINT"`.
- Credentials are resolved by the standard AWS chain (env vars, shared config, profiles, IAM, etc.).
- Region comes from `AWS_REGION` or `AWS_DEFAULT_REGION` and falls back to `S3_REGION` if set.
- Addressing style: controlled by client/SDK configuration, not only env vars.
  - Precedence (highest to lowest):
    1) Explicit setting (CLI flag like `aws s3api --endpoint-url ...` plus `aws configure set s3.addressing_style ...`, or SDK client option such as `o.UsePathStyle`)
    2) SDK/shared config (`~/.aws/config` `s3.addressing_style`)
    3) `S3_ADDRESSING_STYLE` environment variable (setup convenience)
    4) Default: virtual-hosted-style
  - You can always override via an explicit CLI/config setting or client initialization option.

### 3) Run the setup guides

Each script creates any required buckets/objects and cleans up after itself where applicable.

```bash
# If you used Options A or B (default profile):
./s3_basics.sh                   # create bucket, put/get a small object
./s3_bucket_test.sh              # bucket create/head/list/delete
./s3_object_test.sh              # object put/head/get/list
./s3_copy_test.sh                # copy an object within a bucket
./s3_multipart_test.sh           # multipart upload (5 MiB + 2 MiB)

# If you used Option C (custom profile):
export AWS_PROFILE=acs-setup
./s3_basics.sh                   # (same commands as above)

# Or run all tests at once (automatically configures custom profile)
./run_all_tests.sh               # runs all tests with automatic configuration
```

### Notes

- **Default Profile (Options A & B)**: Uses your default AWS CLI configuration
- **Custom Profile (Option C)**: Creates `acs-setup` profile without affecting your default AWS settings
- **Addressing**: Virtual-hosted-style addressing is configured for optimal compatibility


