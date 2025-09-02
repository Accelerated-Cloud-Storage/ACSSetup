#!/bin/bash

# Basic S3 operations test using AWS CLI
# Creates bucket, puts/gets object, verifies content

set -e

# Helper function to get environment variable with default
env_var() {
    local key="$1"
    local default="$2"
    echo "${!key:-$default}"
}

# Configuration
S3_ENDPOINT=$(env_var "S3_ENDPOINT" "https://acceleratedprod.com")
if [ -n "${AWS_REGION:-}" ]; then
    S3_REGION="$AWS_REGION"
elif [ -n "${AWS_DEFAULT_REGION:-}" ]; then
    S3_REGION="$AWS_DEFAULT_REGION"
else
    S3_REGION=$(env_var "S3_REGION" "global")
fi
BUCKET_PREFIX=$(env_var "BUCKET_PREFIX" "smoketest")
# Credentials are sourced from the standard AWS SDK/CLI chain

# Generate unique bucket name (ensure DNS-compliant)
TIMESTAMP=$(date -u +%Y%m%d%H%M%S)
RANDOM_SUFFIX=$(openssl rand -hex 4)
BUCKET_NAME="${BUCKET_PREFIX}-${TIMESTAMP}-${RANDOM_SUFFIX}"
# Ensure bucket name is lowercase and DNS-compliant
BUCKET_NAME=$(echo "$BUCKET_NAME" | tr '[:upper:]' '[:lower:]')
OBJECT_KEY="hello.txt"
BODY="hello world"

echo "Using endpoint: $S3_ENDPOINT"
echo "Region:        $S3_REGION"
echo "Bucket:        $BUCKET_NAME"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    aws s3api delete-object --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
        --endpoint-url "$S3_ENDPOINT" >/dev/null 2>&1 || true
    aws s3api delete-bucket --bucket "$BUCKET_NAME" \
        --endpoint-url "$S3_ENDPOINT" >/dev/null 2>&1 || true
    rm -f /tmp/put_object.txt /tmp/retrieved_object.txt
}

# Set trap for cleanup
trap cleanup EXIT

# Create bucket
aws s3api create-bucket --bucket "$BUCKET_NAME" \
    --endpoint-url "$S3_ENDPOINT"
echo "Created bucket"

# Put object
echo -n "$BODY" > /tmp/put_object.txt
aws s3api put-object --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
    --body /tmp/put_object.txt --endpoint-url "$S3_ENDPOINT" >/dev/null
echo "Put object: $OBJECT_KEY"

# Get object and verify
aws s3api get-object --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
    --endpoint-url "$S3_ENDPOINT" /tmp/retrieved_object.txt >/dev/null
RETRIEVED=$(cat /tmp/retrieved_object.txt 2>/dev/null || echo "")
rm -f /tmp/retrieved_object.txt

echo "Got object: $OBJECT_KEY ($(echo -n "$RETRIEVED" | wc -c) bytes)"

if [ "$RETRIEVED" != "$BODY" ]; then
    echo "ERROR: Retrieved object content mismatch" >&2
    echo "Expected: $BODY" >&2
    echo "Retrieved: $RETRIEVED" >&2
    exit 2
fi

echo "basics test succeeded ✔"
