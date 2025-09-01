#!/bin/bash

# S3 object copy test using AWS CLI
# Creates bucket, puts source object, copies it, and verifies the copy

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
BUCKET_PREFIX=$(env_var "BUCKET_PREFIX" "copytest")

# Generate unique bucket name (ensure DNS-compliant)
TIMESTAMP=$(date -u +%Y%m%d%H%M%S)
RANDOM_SUFFIX=$(openssl rand -hex 4)
BUCKET_NAME="${BUCKET_PREFIX}-${TIMESTAMP}-${RANDOM_SUFFIX}"
# Ensure bucket name is lowercase and DNS-compliant
BUCKET_NAME=$(echo "$BUCKET_NAME" | tr '[:upper:]' '[:lower:]')
SRC_KEY="src/hello.txt"
DST_KEY="dst/hello-copy.txt"
BODY="hello copy api"

echo "Using endpoint: $S3_ENDPOINT"
echo "Region:        $S3_REGION"
echo "Bucket:        $BUCKET_NAME"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    aws s3api delete-object --bucket "$BUCKET_NAME" --key "$SRC_KEY" \
        --endpoint-url "$S3_ENDPOINT" >/dev/null 2>&1 || true
    aws s3api delete-object --bucket "$BUCKET_NAME" --key "$DST_KEY" \
        --endpoint-url "$S3_ENDPOINT" >/dev/null 2>&1 || true
    aws s3api delete-bucket --bucket "$BUCKET_NAME" \
        --endpoint-url "$S3_ENDPOINT" >/dev/null 2>&1 || true
    rm -f /tmp/put_src_object.txt /tmp/retrieved_copy.txt
}

# Set trap for cleanup
trap cleanup EXIT

# Create bucket
aws s3api create-bucket --bucket "$BUCKET_NAME" \
    --endpoint-url "$S3_ENDPOINT"
echo "Created bucket"

# Put source object
echo -n "$BODY" > /tmp/put_src_object.txt
aws s3api put-object --bucket "$BUCKET_NAME" --key "$SRC_KEY" \
    --body /tmp/put_src_object.txt --content-type "text/plain" \
    --endpoint-url "$S3_ENDPOINT" >/dev/null
echo "Put source object"

# Copy object
aws s3api copy-object --bucket "$BUCKET_NAME" --key "$DST_KEY" \
    --copy-source "$BUCKET_NAME/$SRC_KEY" \
    --endpoint-url "$S3_ENDPOINT" >/dev/null
echo "Copied object"

# Verify copied object
if aws s3api get-object --bucket "$BUCKET_NAME" --key "$DST_KEY" \
    --endpoint-url "$S3_ENDPOINT" /tmp/retrieved_copy.txt >/dev/null; then
    RETRIEVED=$(cat /tmp/retrieved_copy.txt 2>/dev/null || echo "")
else
    echo "ERROR: Failed to get copied object" >&2
    exit 1
fi
rm -f /tmp/retrieved_copy.txt

if [ "$RETRIEVED" != "$BODY" ]; then
    echo "ERROR: Copied object content mismatch" >&2
    echo "Expected: '$BODY'" >&2
    echo "Retrieved: '$RETRIEVED'" >&2
    exit 2
fi
echo "Copy verification OK"

echo "Copy object test succeeded ✔"
