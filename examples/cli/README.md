### S3 Examples (AWS CLI)

These examples demonstrate S3-compatible operations using the AWS CLI. They showcase essential S3 operations including bucket management, object CRUD operations, copying, and multipart uploads with proper configuration, error handling, and resource cleanup.

### Prerequisites

- AWS CLI v2 (recommended) or v1
- Network access to your S3 endpoint
- bash shell

### 1) Install AWS CLI

If you don't have AWS CLI installed:

```bash
# For Amazon Linux 2023 / RHEL / CentOS
sudo yum install -y awscli

# Or install AWS CLI v2 (recommended)
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 2) Configure AWS CLI for ACS

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
export S3_ACCESS_KEY="YourActualAccessKey"
export S3_SECRET_KEY="YourActualSecretKey"

source ./configure.sh
```

**Note**: This option creates a custom `acs-examples` profile without affecting your default AWS configuration.

### 3) Run the examples

Each script creates any required buckets/objects and cleans up after itself where applicable.

```bash
# If you used Options A or B (default profile):
./s3_basics.sh                   # create bucket, put/get a small object
./s3_bucket_test.sh              # bucket create/head/list/delete
./s3_object_test.sh              # object put/head/get/list
./s3_copy_test.sh                # copy an object within a bucket
./s3_multipart_test.sh           # multipart upload (5 MiB + 2 MiB)

# If you used Option C (custom profile):
export AWS_PROFILE=acs-examples
./s3_basics.sh                   # (same commands as above)

# Or run all tests at once (automatically configures custom profile)
./run_all_tests.sh               # runs all tests with automatic configuration
```

### Notes

- **Default Profile (Options A & B)**: Uses your default AWS CLI configuration
- **Custom Profile (Option C)**: Creates `acs-examples` profile without affecting your default AWS settings
- **SSL**: Proper SSL verification is used automatically with the valid certificate
- **Addressing**: Virtual-hosted-style addressing is configured for optimal compatibility


