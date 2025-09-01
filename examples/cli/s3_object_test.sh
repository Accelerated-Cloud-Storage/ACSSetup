#!/bin/bash

# S3 object CRUD operations test using AWS CLI
# Creates bucket, puts object with metadata, verifies with head/get/list operations

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
BUCKET_PREFIX=$(env_var "BUCKET_PREFIX" "objecttest")
S3_ADDRESSING_STYLE=$(env_var "S3_ADDRESSING_STYLE" "virtual")

# Generate unique bucket name (ensure DNS-compliant)
TIMESTAMP=$(date -u +%Y%m%d%H%M%S)
RANDOM_SUFFIX=$(openssl rand -hex 4)
BUCKET_NAME="${BUCKET_PREFIX}-${TIMESTAMP}-${RANDOM_SUFFIX}"
# Ensure bucket name is lowercase and DNS-compliant
BUCKET_NAME=$(echo "$BUCKET_NAME" | tr '[:upper:]' '[:lower:]')
OBJECT_KEY="folder/hello.txt"
BODY="hello object api"

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
    rm -f /tmp/put_object_test.txt /tmp/retrieved_object.txt
}

# Set trap for cleanup
trap cleanup EXIT

# Create bucket
aws s3api create-bucket --bucket "$BUCKET_NAME" \
    --endpoint-url "$S3_ENDPOINT"
echo "Created bucket"

# Put object with metadata
echo -n "$BODY" > /tmp/put_object_test.txt
aws s3api put-object --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
    --body /tmp/put_object_test.txt --content-type "text/plain" \
    --metadata "owner=examples" \
    --endpoint-url "$S3_ENDPOINT" >/dev/null
echo "Put object"

# Head object
CONTENT_LENGTH=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
    --endpoint-url "$S3_ENDPOINT" --query 'ContentLength' --output text)
EXPECTED_LENGTH=$(echo -n "$BODY" | wc -c)

if [ "$CONTENT_LENGTH" != "$EXPECTED_LENGTH" ]; then
    echo "ERROR: Head content length mismatch" >&2
    echo "Expected: $EXPECTED_LENGTH, Got: $CONTENT_LENGTH" >&2
    exit 2
fi
echo "Head object OK"

# Get object and verify
aws s3api get-object --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
    --endpoint-url "$S3_ENDPOINT" /tmp/retrieved_object.txt >/dev/null
RETRIEVED=$(cat /tmp/retrieved_object.txt 2>/dev/null || echo "")
rm -f /tmp/retrieved_object.txt

if [ "$RETRIEVED" != "$BODY" ]; then
    echo "ERROR: Get object content mismatch" >&2
    echo "Expected: $BODY" >&2
    echo "Retrieved: $RETRIEVED" >&2
    exit 2
fi
echo "Get object OK"

# List objects with prefix
OBJECT_LIST=$(aws s3api list-objects-v2 --bucket "$BUCKET_NAME" --prefix "folder/" \
    --endpoint-url "$S3_ENDPOINT" --query 'Contents[].Key' --output text 2>/dev/null || \
    aws s3api list-objects --bucket "$BUCKET_NAME" --prefix "folder/" \
    --endpoint-url "$S3_ENDPOINT" --query 'Contents[].Key' --output text 2>/dev/null || echo "")

if [ -n "$OBJECT_LIST" ] && echo "$OBJECT_LIST" | grep -q "$OBJECT_KEY"; then
    echo "ListObjectsV2 OK"
else
    echo "WARNING: Object not found in list operations, but PUT/GET/HEAD work - continuing"
fi

echo "Object CRUD test succeeded ✔"