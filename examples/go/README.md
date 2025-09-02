### S3 Examples (Go, AWS SDK v2)

These examples demonstrate S3-compatible operations using the AWS SDK for Go v2. They showcase essential S3 operations including bucket management, object CRUD operations, copying, and multipart uploads with proper error handling and resource cleanup.

### Prerequisites

- Go 1.20+
- Network access to your S3 endpoint

### 1) Initialize module and download deps

```bash
cd /home/ec2-user/ACSExamples/examples/go
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
```

### 3) Run the examples

### How client initialization works in these examples

- The client sets `o.BaseEndpoint = aws.String(S3_ENDPOINT)` to target your endpoint.
- Region is read from `AWS_REGION`/`AWS_DEFAULT_REGION` (fallback: `S3_REGION`).
- Credentials use the default AWS provider chain (env vars, profiles, IAM, etc.).
- Addressing style defaults to virtual; override with `S3_ADDRESSING_STYLE`.

```bash
go run ./cmd/s3_basics
go run ./cmd/s3_bucket_test
go run ./cmd/s3_object_test
go run ./cmd/s3_copy_test
go run ./cmd/s3_multipart_test
```


