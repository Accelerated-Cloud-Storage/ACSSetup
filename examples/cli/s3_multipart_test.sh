#!/bin/bash

# S3 multipart upload test using AWS CLI
# Creates bucket, performs multipart upload with 2 parts, and verifies

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
BUCKET_PREFIX=$(env_var "BUCKET_PREFIX" "mpuploadtest")
S3_ADDRESSING_STYLE=$(env_var "S3_ADDRESSING_STYLE" "virtual")

# Generate unique bucket name (ensure DNS-compliant and shorter)
TIMESTAMP=$(date -u +%Y%m%d%H%M%S)
RANDOM_SUFFIX=$(openssl rand -hex 3)  # Shorter suffix
BUCKET_NAME="mp-${TIMESTAMP}-${RANDOM_SUFFIX}"     # Shorter prefix
# Ensure bucket name is lowercase and DNS-compliant
BUCKET_NAME=$(echo "$BUCKET_NAME" | tr '[:upper:]' '[:lower:]')
OBJECT_KEY="large/data.bin"

echo "Using endpoint: $S3_ENDPOINT"
echo "Region:        $S3_REGION"
echo "Bucket:        $BUCKET_NAME"

# Create test data files
PART1_FILE="/tmp/part1.bin"
PART2_FILE="/tmp/part2.bin"
COMBINED_FILE="/tmp/combined.bin"

# Create 5MB part1 (minimum part size) and 2MB part2
dd if=/dev/zero of="$PART1_FILE" bs=1024 count=5120 2>/dev/null
tr '\0' 'a' < "$PART1_FILE" > "${PART1_FILE}.tmp" && mv "${PART1_FILE}.tmp" "$PART1_FILE"

dd if=/dev/zero of="$PART2_FILE" bs=1024 count=2048 2>/dev/null
tr '\0' 'b' < "$PART2_FILE" > "${PART2_FILE}.tmp" && mv "${PART2_FILE}.tmp" "$PART2_FILE"

# Create expected combined file for verification
cat "$PART1_FILE" "$PART2_FILE" > "$COMBINED_FILE"
TOTAL_SIZE=$(wc -c < "$COMBINED_FILE" | tr -d '[:space:]')

UPLOAD_ID=""

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    if [ -n "$UPLOAD_ID" ]; then
        aws s3api abort-multipart-upload --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
            --upload-id "$UPLOAD_ID" --endpoint-url "$S3_ENDPOINT" >/dev/null 2>&1 || true
    fi
    aws s3api delete-object --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
        --endpoint-url "$S3_ENDPOINT" >/dev/null 2>&1 || true
    aws s3api delete-bucket --bucket "$BUCKET_NAME" \
        --endpoint-url "$S3_ENDPOINT" >/dev/null 2>&1 || true
    rm -f "$PART1_FILE" "$PART2_FILE" "$COMBINED_FILE" /tmp/retrieved_multipart.bin
}

# Set trap for cleanup
trap cleanup EXIT

# Create bucket
aws s3api create-bucket --bucket "$BUCKET_NAME" \
    --endpoint-url "$S3_ENDPOINT"
echo "Created bucket"

# Initiate multipart upload
UPLOAD_OUTPUT=$(aws s3api create-multipart-upload --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
    --content-type "application/octet-stream" \
    --endpoint-url "$S3_ENDPOINT")
UPLOAD_ID=$(echo "$UPLOAD_OUTPUT" | jq -r '.UploadId // empty')
if [ -z "$UPLOAD_ID" ]; then
    echo "ERROR: Failed to obtain UploadId from create-multipart-upload response" >&2
    exit 1
fi
echo "Initiated MPU: $UPLOAD_ID"

# Upload part 1
PART1_OUTPUT=$(aws s3api upload-part --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
    --part-number 1 --upload-id "$UPLOAD_ID" --body "$PART1_FILE" \
    --endpoint-url "$S3_ENDPOINT")
# Extract and normalize ETag (remove any surrounding quotes)
ETAG1=$(echo "$PART1_OUTPUT" | jq -r '.ETag // empty')
ETAG1=${ETAG1//\"/}
ETAG1=${ETAG1//\\/}
if [ -z "$ETAG1" ]; then
    echo "ERROR: Failed to extract ETag for part 1" >&2
    exit 1
fi
echo "Uploaded part 1"

# Upload part 2
PART2_OUTPUT=$(aws s3api upload-part --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
    --part-number 2 --upload-id "$UPLOAD_ID" --body "$PART2_FILE" \
    --endpoint-url "$S3_ENDPOINT")
# Extract and normalize ETag (remove any surrounding quotes)
ETAG2=$(echo "$PART2_OUTPUT" | jq -r '.ETag // empty')
ETAG2=${ETAG2//\"/}
ETAG2=${ETAG2//\\/}
if [ -z "$ETAG2" ]; then
    echo "ERROR: Failed to extract ETag for part 2" >&2
    exit 1
fi
echo "Uploaded part 2"

# Complete multipart upload (build JSON safely with jq)
PARTS_JSON=$(jq -n --arg e1 "$ETAG1" --arg e2 "$ETAG2" '{
    Parts: [
        {ETag: $e1, PartNumber: 1},
        {ETag: $e2, PartNumber: 2}
    ]
}')

aws s3api complete-multipart-upload --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
    --upload-id "$UPLOAD_ID" --multipart-upload "$PARTS_JSON" \
    --endpoint-url "$S3_ENDPOINT" >/dev/null
echo "Completed MPU"

# Verify with HEAD
HEAD_OUTPUT=$(aws s3api head-object --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
    --endpoint-url "$S3_ENDPOINT")
HEAD_SIZE=$(echo "$HEAD_OUTPUT" | grep -o '"ContentLength": [0-9]*' | grep -o '[0-9]*')

if [ "$HEAD_SIZE" != "$TOTAL_SIZE" ]; then
    echo "ERROR: Head size mismatch after MPU" >&2
    echo "Expected: $TOTAL_SIZE, Got: $HEAD_SIZE" >&2
    exit 2
fi

# Verify with GET
aws s3api get-object --bucket "$BUCKET_NAME" --key "$OBJECT_KEY" \
    --endpoint-url "$S3_ENDPOINT" /tmp/retrieved_multipart.bin >/dev/null

if ! cmp -s "$COMBINED_FILE" /tmp/retrieved_multipart.bin; then
    echo "ERROR: Retrieved content mismatch after MPU" >&2
    exit 2
fi

echo "Multipart upload test succeeded ✔"
