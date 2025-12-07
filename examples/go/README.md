### S3 & IAM Setup (Go, AWS SDK v2)

These setup guides demonstrate S3-compatible operations using the AWS SDK for Go v2. They showcase essential S3 operations including bucket management, object CRUD operations, copying, multipart uploads, and an IAM access key lifecycle example that works with your current IAM identity or a specified user.

### Prerequisites

- Go 1.20+
- Network access to your S3 endpoint

### 1) Initialize module and download deps

```bash
cd /home/ec2-user/ACSSetup/examples/go
go mod tidy
```

### 2) Configure your environment for an S3-compatible endpoint

Set these variables so the Go SDK targets your S3-compatible store:

```bash
export S3_ENDPOINT="https://acceleratedprod.com"   # ACS S3-compatible endpoint URL
export AWS_REGION="global"                          # Or set AWS_DEFAULT_REGION
export S3_ADDRESSING_STYLE="virtual"               # virtual | path | auto

# S3-compatible credentials (standard AWS env vars)
export AWS_ACCESS_KEY_ID="<YOUR_ACCESS_KEY_ID>"
export AWS_SECRET_ACCESS_KEY="<YOUR_SECRET_ACCESS_KEY>"

# Optional IAM override
export IAM_ENDPOINT="$S3_ENDPOINT"  # IAM endpoint override
```

### 3) Run the setup guides

Each program creates any required buckets/objects and cleans up after itself where applicable.

```bash
cd cmd/s3_basics && go run .             # create bucket, put/get a small object
cd cmd/s3_bucket_test && go run .        # bucket create/head/list/delete
cd cmd/s3_object_test && go run .        # object put/head/get/list
cd cmd/s3_copy_test && go run .          # copy an object within a bucket
cd cmd/s3_multipart_test && go run .     # multipart upload (5 MiB + 2 MiB)
cd cmd/iam_examples && go run .          # IAM access key lifecycle with bucket-scoped policy (create/attach/detach/delete)
```

### How client initialization works in these setup guides

- The client sets `