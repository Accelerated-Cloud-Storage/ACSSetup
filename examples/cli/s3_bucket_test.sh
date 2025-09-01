#!/bin/bash

# S3 bucket lifecycle test using AWS CLI
# Creates bucket, verifies with head/list operations, then deletes

set -e

# Helper function to get environment variable with default
env_var() {
    local key="$1"
    local default="$2"
    echo "${!key:-$default}"
}

# Configuration
S3_ENDPOINT=$(env_var "S3_ENDPOINT" "https://acceleratedprod.com")
S3_REGION=$(env_var "S3_REGION" "global")
BUCKET_PREFIX=$(env_var "BUCKET_PREFIX" "acs-bucket-test")

# Generate unique bucket name (ensure DNS-compliant)
TIMESTAMP=$(date -u +%Y%m%d%H%M%S)
RANDOM_SUFFIX=$(openssl rand -hex 4)
BUCKET_NAME="${BUCKET_PREFIX}-${TIMESTAMP}-${RANDOM_SUFFIX}"
# Ensure bucket name is lowercase and DNS-compliant
BUCKET_NAME=$(echo "$BUCKET_NAME" | tr '[:upper:]' '[:lower:]')

echo "Using endpoint: $S3_ENDPOINT"
echo "Region:        $S3_REGION"
echo "Bucket:        $BUCKET_NAME"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    aws s3api delete-bucket --bucket "$BUCKET_NAME" \
        --endpoint-url "$S3_ENDPOINT" >/dev/null 2>&1 || true
}

# Set trap for cleanup
trap cleanup EXIT

# Create bucket
aws s3api create-bucket --bucket "$BUCKET_NAME" \
    --endpoint-url "$S3_ENDPOINT"
echo "Created bucket"

# Head bucket
aws s3api head-bucket --bucket "$BUCKET_NAME" \
    --endpoint-url "$S3_ENDPOINT"
echo "Head bucket OK"

# List buckets and verify presence
BUCKET_LIST=$(aws s3api list-buckets --endpoint-url "$S3_ENDPOINT" --output text --query 'Buckets[].Name')
if ! echo "$BUCKET_LIST" | grep -q "$BUCKET_NAME"; then
    echo "ERROR: Created bucket not found in list_buckets()" >&2
    exit 2
fi
echo "List buckets contains created bucket"

echo "Bucket lifecycle test succeeded ✔"
