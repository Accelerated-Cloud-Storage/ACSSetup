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

### 2) Configure your client for ACS (endpoint, region, addressing style)

Set the endpoint, region, addressing style, and credentials so the SDK targets ACS:

```bash
export S3_ENDPOINT="https://acceleratedprod.com"   # ACS S3 endpoint
export S3_REGION="global"                           # ACS region
export S3_ADDRESSING_STYLE="virtual"               # virtual | path | auto (ACS defaults to virtual)

export S3_ACCESS_KEY="ExampleAccessKey"
export S3_SECRET_KEY="ExampleSecretKey"
```

### 3) Run the examples

```bash
go run ./cmd/s3_basics
go run ./cmd/s3_bucket_test
go run ./cmd/s3_object_test
go run ./cmd/s3_copy_test
go run ./cmd/s3_multipart_test
```


