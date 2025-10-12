#!/bin/bash

# IAM access key lifecycle test using AWS CLI
# Creates a temporary access key, lists keys, marks it inactive, and deletes it

set -Eeuo pipefail

env_var() {
    local key="$1"
    local default="$2"
    echo "${!key:-$default}"
}

IAM_ENDPOINT=$(env_var "IAM_ENDPOINT" "$(env_var "S3_ENDPOINT" "https://acceleratedprod.com")")
if [ -n "${AWS_REGION:-}" ]; then
    IAM_REGION="$AWS_REGION"
elif [ -n "${AWS_DEFAULT_REGION:-}" ]; then
    IAM_REGION="$AWS_DEFAULT_REGION"
else
    IAM_REGION=$(env_var "IAM_REGION" "global")
fi

ACCESS_KEY_ID=""

cleanup() {
    if [ -n "$ACCESS_KEY_ID" ]; then
        aws iam delete-access-key \
            --access-key-id "$ACCESS_KEY_ID" \
            --endpoint-url "$IAM_ENDPOINT" \
            --output json >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT

echo "Using endpoint: $IAM_ENDPOINT"
echo "Region:        $IAM_REGION"
echo "Target user:   [current IAM identity]"

CREATE_OUTPUT=$(aws iam create-access-key \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json)
ACCESS_KEY_ID=$(echo "$CREATE_OUTPUT" | jq -r '.AccessKey.AccessKeyId // empty')
if [ -z "$ACCESS_KEY_ID" ]; then
    echo "ERROR: Failed to create access key" >&2
    exit 1
fi
MASKED_KEY="${ACCESS_KEY_ID:0:4}****"
echo "Created access key: $MASKED_KEY"

KEY_LIST=$(aws iam list-access-keys \
    --endpoint-url "$IAM_ENDPOINT" \
    --query 'AccessKeyMetadata[].AccessKeyId' \
    --output text)
if ! echo "$KEY_LIST" | grep -q "$ACCESS_KEY_ID"; then
    echo "ERROR: Created access key not found in list" >&2
    exit 2
fi
echo "Listed access keys (found created key)"

aws iam update-access-key \
    --access-key-id "$ACCESS_KEY_ID" \
    --status Inactive \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json >/dev/null
echo "Updated access key to inactive"

aws iam delete-access-key \
    --access-key-id "$ACCESS_KEY_ID" \
    --endpoint-url "$IAM_ENDPOINT" \
    --output json >/dev/null
echo "Deleted access key"
ACCESS_KEY_ID=""

echo "IAM access key test succeeded ✔"

